import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/pos_controller.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/payzen_logo.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/product_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/inventory/low_stock_notification_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _barcodeFocusNode = FocusNode();
  final _barcodeCtrl = TextEditingController();

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(POSController());
    final size       = MediaQuery.of(context).size;
    final isTablet   = size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: isTablet
          ? _buildTabletLayout(controller, size)
          : _buildPhoneLayout(controller, size),
    );
  }

  // ── TABLET LAYOUT ─────────────────────────────────────────────────────────
  Widget _buildTabletLayout(POSController controller, Size size) {
    return Row(
      children: [
        _buildSidebar(isTablet: true),
        Expanded(flex: 5, child: _buildProductArea(controller, size, true)),
        SizedBox(width: 300, child: _buildOrderPanel(controller, size, true)),
      ],
    );
  }

  // ── PHONE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildPhoneLayout(POSController controller, Size size) {
    return SafeArea(
      child: Column(
        children: [
          _buildPhoneHeader(controller),
          Expanded(child: _buildProductArea(controller, size, false)),
          Obx(() => controller.hasItemsInCart
              ? _buildCartBar(controller)
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  // ── SIDEBAR ───────────────────────────────────────────────────────────────
  Widget _buildSidebar({bool isTablet = false}) {
    final authService = Get.find<AuthService>();
    final user        = authService.currentUser;
    final sidebarW    = isTablet ? 88.0 : 72.0;

    final isCashier = user?.isCashier == true;
    final lowStockSvc = Get.find<LowStockNotificationService>();
    final navItems = [
      _SideNavItem(icon: Icons.home_rounded,           label: 'Home',    onTap: () => Get.offAllNamed('/dashboard')),
      _SideNavItem(icon: Icons.point_of_sale_rounded,  label: 'Kasir',   onTap: null, selected: true),
      if (!isCashier)
        _SideNavItem(icon: Icons.inventory_2_rounded,  label: 'Produk',  onTap: () => Get.toNamed('/inventory'), badgeService: lowStockSvc),
      _SideNavItem(icon: Icons.receipt_long_rounded,   label: 'Riwayat', onTap: () => Get.toNamed('/sales-report')),
      if (!isCashier)
        _SideNavItem(icon: Icons.settings_rounded,     label: 'Setelan', onTap: () => Get.toNamed('/settings')),
    ];

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
            const SizedBox(height: 16),

            // ── Logo ──
            const PayzenLogo.icon(size: 44, ringColor: Colors.white),
            const SizedBox(height: 12),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color:  Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),

            // ── Nav items (scrollable jika perlu) ──
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: navItems.map((item) => _buildNavItem(item)).toList(),
                ),
              ),
            ),

            // ── Bottom items (fixed, tidak scroll) ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color:  Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),

            // Branch switcher — hanya untuk owner & manager, hidden untuk kasir
            Obx(() {
              final u = authService.currentUser;
              if (u == null || u.isCashier) return const SizedBox.shrink();
              final branch = authService.selectedBranch;
              return GestureDetector(
                onTap: () => _showBranchSwitcher(authService),
                child: _sidebarBottomItem(
                  icon:  Icons.storefront_rounded,
                  label: branch?.name ?? 'Pilih',
                ),
              );
            }),

            // Customer Display
            Obx(() {
              final branchId = authService.selectedBranch?.id
                  ?? authService.currentUser?.branchId;
              if (branchId == null) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => _showDisplayQR(branchId),
                child: _sidebarBottomItem(
                  icon:  Icons.monitor_rounded,
                  label: 'Display',
                ),
              );
            }),

            // Connectivity
            const ConnectivityDot(),
            const SizedBox(height: 6),

            // Avatar + nama — tap untuk info user & logout
            GestureDetector(
              onTap: () => _showUserMenu(authService),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 36,
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
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user != null ? user.name.split(' ').first : 'User',
                    style: TextStyle(
                      color:    Colors.white.withValues(alpha: 0.5),
                      fontSize: 8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(_SideNavItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve:    Curves.easeOutBack,
        width:    double.infinity,
        margin:   const EdgeInsets.symmetric(vertical: 4),
        padding:  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Left indicator pill — sama persis dengan dashboard
            if (item.selected)
              Positioned(
                left: 0,
                child: Container(
                  width: 5,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin:  Alignment.topCenter,
                      end:    Alignment.bottomCenter,
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42), Color(0xFFFF6B35)],
                      stops:  [0.0, 0.5, 1.0],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight:    Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:      const Color(0xFFFF6B35).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset:     const Offset(2, 0),
                      ),
                    ],
                  ),
                ),
              ),
            // Icon + label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale:    item.selected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: item.selected
                        ? const BoxDecoration(
                            gradient: LinearGradient(
                              begin:  Alignment.topLeft,
                              end:    Alignment.bottomRight,
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42), Color(0xFFFFA05F)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            boxShadow: [
                              BoxShadow(
                                color:      Color(0xFFFF6B35),
                                blurRadius: 10,
                                offset:     Offset(0, 4),
                              ),
                            ],
                          )
                        : BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: Builder(builder: (_) {
                      final iconWidget = Icon(
                        item.icon,
                        color: item.selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        size:  item.selected ? 22 : 20,
                      );
                      return item.badgeService != null
                          ? item.badgeService!.buildBadge(child: iconWidget)
                          : iconWidget;
                    }),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:      9,
                    fontWeight:    item.selected ? FontWeight.w700 : FontWeight.w500,
                    color:         item.selected
                        ? const Color(0xFFFF6B35)
                        : Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 0.3,
                    height:        1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarBottomItem({required IconData icon, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ── PHONE HEADER ──────────────────────────────────────────────────────────
  Widget _buildPhoneHeader(POSController controller) {
    final authService = Get.find<AuthService>();
    final user        = authService.currentUser;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D26)),
          ),
          const SizedBox(width: 12),
          const Text('Kasir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
          const Spacer(),
          // Tombol branch — hanya owner & manager, hidden untuk kasir
          Obx(() {
            final u = authService.currentUser;
            if (u == null || u.isCashier) return const SizedBox.shrink();
            final branch = authService.selectedBranch;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showBranchSwitcher(authService),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFFFF6B35)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            branch?.name ?? 'Cabang',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded, size: 13, color: Color(0xFF8A8F9E)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            );
          }),
          const ConnectivityDot(),
        ],
      ),
    );
  }

  // ── PRODUCT AREA ──────────────────────────────────────────────────────────
  Widget _buildProductArea(POSController controller, Size size, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductHeader(controller, isTablet),
        _buildBarcodeInputField(controller),
        _buildCategoryChips(controller),
        Expanded(
          child: Obx(() {
            if (controller.products.isEmpty) return _buildEmptyProducts(controller);
            if (controller.filteredProducts.isEmpty) return _buildEmptyFiltered(controller);
            return _buildProductGrid(controller, isTablet);
          }),
        ),
      ],
    );
  }

  Widget _buildProductHeader(POSController controller, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          if (isTablet) ...[
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D26), size: 20),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: TextField(
                onChanged: controller.searchProducts,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Tombol Kamera Scanner ──
          GestureDetector(
            onTap: () => _showCameraScanner(context, Get.find<POSController>()),
            child: Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D26),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          // ── Tombol Refresh dari Backend ──
          Obx(() => GestureDetector(
            onTap: controller.isLoadingProducts
                ? null
                : () => controller.syncProductsFromBackend(),
            child: Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: controller.isLoadingProducts
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                      ),
                    )
                  : const Icon(Icons.sync_rounded, color: Color(0xFFFF6B35), size: 22),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBarcodeInputField(POSController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: TextField(
          controller: _barcodeCtrl,
          focusNode: _barcodeFocusNode,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Scan barcode keyboard / ketik barcode...',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.barcode_reader, color: Color(0xFFFF6B35), size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onSubmitted: (value) {
            final barcode = value.trim();
            if (barcode.isNotEmpty) {
              controller.addToCartByBarcode(barcode);
              _barcodeCtrl.clear();
              _barcodeFocusNode.requestFocus();
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChips(POSController controller) {
    return Obx(() {
      final categories = controller.categories;
      final selectedId = controller.selectedCategoryId;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1, // +1 untuk chip "Semua"
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                // Chip "Semua"
                if (i == 0) {
                  final selected = selectedId == null;
                  return _buildCategoryChip(
                    label: 'Semua',
                    icon: Icons.grid_view_rounded,
                    selected: selected,
                    onTap: () => controller.selectCategory(null),
                  );
                }
                final cat      = categories[i - 1];
                final selected = selectedId == cat.id;
                return _buildCategoryChip(
                  label:    cat.name,
                  icon:     _categoryIcon(cat.name),
                  selected: selected,
                  onTap:    () => controller.selectCategory(cat.id),
                );
              },
            ),
          ),
          // Subtle divider
          const SizedBox(height: 10),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFFEEEEEE),
          ),
        ],
      );
    });
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFFFF6B35).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: selected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:  15,
              color: selected ? Colors.white : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pilih icon berdasarkan nama kategori (fallback ke tag icon)
  IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('minum') || n.contains('drink') || n.contains('beverage')) {
      return Icons.local_drink_rounded;
    }
    if (n.contains('makan') || n.contains('food') || n.contains('snack') || n.contains('makanan')) {
      return Icons.fastfood_rounded;
    }
    if (n.contains('kue') || n.contains('cake') || n.contains('roti') || n.contains('bakery')) {
      return Icons.cake_rounded;
    }
    if (n.contains('es') || n.contains('ice') || n.contains('cold')) {
      return Icons.ac_unit_rounded;
    }
    if (n.contains('kopi') || n.contains('coffee') || n.contains('teh') || n.contains('tea')) {
      return Icons.coffee_rounded;
    }
    if (n.contains('elektronik') || n.contains('electric')) {
      return Icons.electrical_services_rounded;
    }
    if (n.contains('pakaian') || n.contains('fashion') || n.contains('baju')) {
      return Icons.checkroom_rounded;
    }
    return Icons.label_rounded;
  }

  Widget _buildProductGrid(POSController controller, bool isTablet) {
    return Obx(() {
      final products = controller.filteredProducts;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 4 : 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isTablet ? 0.72 : 0.68,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => _buildProductCard(products[i], controller),
      );
    });
  }

  Widget _buildProductCard(Product product, POSController controller) {
    final stock        = product.localStock ?? 0;
    final isLowStock   = stock > 0 && stock <= product.minStock;
    final isOutOfStock = stock <= 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => controller.addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: isOutOfStock ? const Color(0xFFF5F5F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gambar / Placeholder ──────────────────────
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: product.image != null && product.image!.isNotEmpty
                          ? Image.network(
                              product.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _productPlaceholder(product),
                            )
                          : _productPlaceholder(product),
                    ),
                  ),
                  // Overlay habis
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: const Center(
                          child: Text('Habis',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                      ),
                    ),
                  // Badge "+" di pojok kanan bawah (kalau tersedia)
                  if (!isOutOfStock)
                    Positioned(
                      right: 6, bottom: 6,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D26),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info di bawah ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama produk
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isOutOfStock ? Colors.grey[400] : const Color(0xFF1A1D26),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Harga
                  Text(
                    _currency.format(product.price),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock ? Colors.grey[400] : const Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Badge stok
                  _buildStockBadge(stock, isLowStock, isOutOfStock, product.unit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock, bool isLowStock, bool isOutOfStock, String unit) {
    final Color bgColor;
    final Color textColor;
    final String label;
    final IconData icon;

    if (isOutOfStock) {
      bgColor   = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFE53935);
      label     = 'Habis';
      icon      = Icons.remove_shopping_cart_rounded;
    } else if (isLowStock) {
      bgColor   = const Color(0xFFFF6B35);
      textColor = Colors.white;
      label     = 'Stok: $stock $unit';
      icon      = Icons.warning_amber_rounded;
    } else {
      bgColor   = const Color(0xFFF0FFF4);
      textColor = const Color(0xFF2E7D32);
      label     = 'Stok: $stock $unit';
      icon      = Icons.inventory_2_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: textColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder(Product product) {
    final pairs = [
      [const Color(0xFFFFE0D0), const Color(0xFFFF6B35)],
      [const Color(0xFFD0E8FF), const Color(0xFF2196F3)],
      [const Color(0xFFD0FFE8), const Color(0xFF4CAF50)],
      [const Color(0xFFFFD0F0), const Color(0xFF9C27B0)],
    ];
    final pair = pairs[product.name.length % pairs.length];
    return Container(
      decoration: BoxDecoration(color: pair[0], borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(product.name[0].toUpperCase(),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: pair[1])),
      ),
    );
  }

  Widget _buildEmptyProducts(POSController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Tidak ada produk', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 4),
          Text('Coba ambil data dari server', style: TextStyle(color: Colors.grey[300], fontSize: 12)),
          const SizedBox(height: 16),
          Obx(() => ElevatedButton.icon(
            onPressed: controller.isLoadingProducts
                ? null
                : () => controller.syncProductsFromBackend(),
            icon: controller.isLoadingProducts
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_download_rounded, size: 16),
            label: Text(controller.isLoadingProducts ? 'Mengambil data...' : 'Ambil dari Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyFiltered(POSController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Tidak ada produk di kategori ini',
              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Coba pilih kategori lain',
              style: TextStyle(color: Colors.grey[300], fontSize: 12)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => controller.selectCategory(null),
            child: const Text('Tampilkan Semua', style: TextStyle(color: Color(0xFFFF6B35))),
          ),
        ],
      ),
    );
  }

  // ── ORDER PANEL ───────────────────────────────────────────────────────────
  Widget _buildOrderPanel(POSController controller, Size size, bool isTablet) {
    final authService = Get.find<AuthService>();
    final user = authService.currentUser;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris judul + tombol branch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Order',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26)),
                    ),
                    // Tombol switch branch — hanya owner & manager, hidden untuk kasir
                    Obx(() {
                      final u = authService.currentUser;
                      if (u == null || u.isCashier) return const SizedBox.shrink();
                      final branch = authService.selectedBranch;
                      return GestureDetector(
                        onTap: () => _showBranchSwitcher(authService),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 130),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color:        const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(10),
                            border:       Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFFFF6B35)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  branch?.name ?? 'Pilih Cabang',
                                  style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1D26),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.expand_more_rounded, size: 13, color: Color(0xFF8A8F9E)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                // Baris avatar + nama kasir + tombol Hold
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (user?.name ?? 'K')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user != null ? user.name : 'Kasir',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8A8F9E)),
                      ),
                    ),
                    // Tombol Hold + badge jumlah held
                    Obx(() => GestureDetector(
                      onTap: () => _showHoldTransactionDialog(controller),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: controller.heldTransactionCount > 0
                              ? const Color(0xFFFFE0D0)
                              : const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: controller.heldTransactionCount > 0
                                ? const Color(0xFFFF6B35)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 13,
                              color: controller.heldTransactionCount > 0
                                  ? const Color(0xFFFF6B35)
                                  : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              controller.heldTransactionCount > 0
                                  ? 'Tahan (${controller.heldTransactionCount})'
                                  : 'Tahan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: controller.heldTransactionCount > 0
                                    ? const Color(0xFFFF6B35)
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),

          // ── Cart list ──
          Expanded(
            child: Obx(() {
              if (controller.cartItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/animations/cart_empty.json',
                        width: 140,
                        height: 140,
                        repeat: true,
                      ),
                      const SizedBox(height: 4),
                      Text('Keranjang kosong',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Pilih produk untuk ditambahkan',
                          style: TextStyle(color: Colors.grey[300], fontSize: 11)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: controller.cartItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (_, i) => _buildCartItem(controller.cartItems[i], controller),
              );
            }),
          ),

          // ── Summary ──
          _buildOrderSummary(controller),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, POSController controller) {
    final pairs = <List<Color>>[
      [const Color(0xFFFFE0D0), const Color(0xFFFF6B35)],
      [const Color(0xFFD0E8FF), const Color(0xFF2196F3)],
      [const Color(0xFFD0FFE8), const Color(0xFF4CAF50)],
      [const Color(0xFFFFD0F0), const Color(0xFF9C27B0)],
    ];
    final pair = pairs[item.product.name.length % pairs.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // ── Thumbnail ──
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: pair[0],
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.product.image != null && item.product.image!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(item.product.image!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(item.product.name[0].toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: pair[1], fontSize: 20)),
                        )),
                  )
                : Center(
                    child: Text(item.product.name[0].toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: pair[1], fontSize: 22)),
                  ),
          ),
          const SizedBox(width: 12),

          // ── Name & price ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1D26))),
                const SizedBox(height: 4),
                Text(_currency.format(item.product.price),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8A8F9E))),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Qty controls ──
          Row(
            children: [
              _qtyBtn(
                Icons.remove_rounded,
                () => controller.updateCartItemQuantity(item.product.id!, item.quantity - 1),
                filled: false,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D26))),
              ),
              _qtyBtn(
                Icons.add_rounded,
                () => controller.updateCartItemQuantity(item.product.id!, item.quantity + 1),
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF1A1D26) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: filled ? const Color(0xFF1A1D26) : const Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Icon(icon, size: 15, color: filled ? Colors.white : const Color(0xFF1A1D26)),
      ),
    );
  }

  Widget _buildOrderSummary(POSController controller) {
    return Obx(() {
      final subtotal = controller.totalAmount + controller.totalDiscount;
      final discount = controller.totalDiscount;
      final total    = controller.totalAmount;

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[100]!)),
        ),
        child: Column(
          children: [
            _sumRow('Subtotal', _currency.format(subtotal)),
            if (discount > 0)
              _sumRow('Diskon', '- ${_currency.format(discount)}', valueColor: Colors.red),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _sumRow('Total', _currency.format(total), bold: true, fontSize: 16),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: controller.hasItemsInCart ? () => Get.toNamed('/checkout') : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  disabledForegroundColor: Colors.grey[400],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  controller.hasItemsInCart ? 'Continue' : 'Pilih produk dahulu',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _sumRow(String label, String value,
      {bool bold = false, double fontSize = 13, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
              fontSize: fontSize,
              color: bold ? const Color(0xFF1A1D26) : const Color(0xFF8A8F9E),
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1A1D26))),
        ],
      ),
    );
  }

  Widget _buildCartBar(POSController controller) {
    return GestureDetector(
      onTap: () => Get.toNamed('/checkout'),
      child: Obx(() => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        color: const Color(0xFF1A1D26),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${controller.cartItems.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            const Text('Lihat Keranjang',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_currency.format(controller.totalAmount),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      )),
    );
  }

  // ── USER MENU (info akun + logout) ────────────────────────────────────────
  void _showUserMenu(AuthService authService) {
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
                  Get.back(); // tutup bottom sheet dulu
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

  // ── BRANCH SWITCHER ───────────────────────────────────────────────────────
  void _showBranchSwitcher(AuthService authService) {
    final controller  = Get.find<POSController>();
    final branches    = authService.branches;
    final current     = authService.selectedBranch;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFFFF6B35), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pilih Cabang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
                    Text('${branches.length} cabang tersedia',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[100]),
            const SizedBox(height: 8),

            // ── Branch list ──
            ...branches.map((branch) {
              final isActive = current?.id == branch.id;
              return GestureDetector(
                onTap: () async {
                  Get.back();
                  await authService.selectBranch(branch);
                  // Reload produk sesuai branch baru
                  await controller.syncProductsFromBackend(silent: false);
                  Get.snackbar(
                    'Cabang Diubah',
                    'Sekarang aktif: ${branch.name}',
                    backgroundColor: const Color(0xFF1A1D26).withValues(alpha: 0.9),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        isActive
                        ? const Color(0xFFFF6B35).withValues(alpha: 0.08)
                        : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(
                      color: isActive ? const Color(0xFFFF6B35) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color:        isActive
                              ? const Color(0xFFFF6B35)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.store_rounded,
                          size:  20,
                          color: isActive ? Colors.white : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(branch.name,
                                style: TextStyle(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w600,
                                  color:      isActive
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF1A1D26),
                                )),
                            if (branch.city != null && branch.city!.isNotEmpty)
                              Text(branch.city!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            if (branch.code != null && branch.code!.isNotEmpty)
                              Text('Kode: ${branch.code}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color:  Color(0xFFFF6B35),
                            shape:  BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              );
            }),

            if (branches.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Tidak ada cabang tersedia',
                      style: TextStyle(color: Colors.grey[400])),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Hold/Resume Dialog helpers (standalone) ────────────────────────────────

void _showHoldTransactionDialog(POSController controller) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setS) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),

                // Title row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0D0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pause_circle_rounded,
                            color: Color(0xFFFF6B35), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Transaksi Ditahan',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1D26))),
                      const Spacer(),
                      // Tombol tahan transaksi saat ini
                      if (controller.hasItemsInCart)
                        GestureDetector(
                          onTap: () async {
                            Get.back();
                            await _showHoldLabelDialog(controller);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D26),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.pause_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Tahan Ini',
                                    style: TextStyle(color: Colors.white, fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: Colors.grey[100]),

                // List held transactions
                Expanded(
                  child: Obx(() {
                    if (controller.heldTransactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pause_circle_outline_rounded, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Tidak ada transaksi yang ditahan',
                                style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text('Tekan "Tahan Ini" untuk menyimpan transaksi',
                                style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: controller.heldTransactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final held = controller.heldTransactions[i];
                        final label = held['label'] as String? ?? 'Transaksi';
                        final total = (held['total'] as num?)?.toDouble() ?? 0.0;
                        final createdAt = held['created_at'] as String? ?? '';
                        final holdId = held['id'] as int;
                        String timeStr = '';
                        try {
                          timeStr = DateFormat('dd/MM HH:mm').format(DateTime.parse(createdAt));
                        } catch (_) {}

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE0D0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.pause_rounded, color: Color(0xFFFF6B35), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: const TextStyle(fontWeight: FontWeight.w700,
                                            fontSize: 13, color: Color(0xFF1A1D26))),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(currency.format(total),
                                            style: const TextStyle(fontSize: 12,
                                                color: Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 8),
                                        Text(timeStr,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Resume button
                              GestureDetector(
                                onTap: () async {
                                  Get.back();
                                  await controller.resumeTransaction(holdId);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Lanjutkan',
                                      style: TextStyle(color: Colors.white, fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Delete button
                              GestureDetector(
                                onTap: () async {
                                  await controller.deleteHeldTransaction(holdId);
                                },
                                child: Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded,
                                      color: Colors.red[400], size: 15),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> _showHoldLabelDialog(POSController controller) async {
    final labelCtrl = TextEditingController(
        text: 'Transaksi ${DateFormat('HH:mm').format(DateTime.now())}');
    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Beri Nama Transaksi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: labelCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nama / catatan transaksi',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.label_outline_rounded, color: Colors.grey[400], size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await controller.holdTransaction(label: labelCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tahan Transaksi'),
          ),
        ],
      ),
    );
  }

  // ── Customer Display QR Dialog ──────────────────────────────────────────
  void _showDisplayQR(int branchId) {
    // Ganti /api dengan URL web biasa
    final baseWeb = AppConstants.baseUrl.replaceAll('/api', '');
    final url     = '$baseWeb/display/$branchId';

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Customer Display',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan QR atau buka URL di browser device customer',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: QrImageView(
                    data:            url,
                    version:         QrVersions.auto,
                    size:            200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // URL box + copy button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          url,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1A1D26)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: url));
                          Get.snackbar(
                            'Disalin',
                            'URL berhasil disalin',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF4CAF50),
                            colorText: Colors.white,
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFFF6B35)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFFFF6B35))),
          ),
        ],
      ),
      barrierColor: Colors.black54,
    );
  }

  void _showCameraScanner(BuildContext context, POSController controller) {
    bool _scanned = false;
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        content: SizedBox(
          width: 320,
          height: 380,
          child: Stack(
            children: [
              // Scanner view
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  onDetect: (capture) {
                    if (_scanned) return;
                    final barcode = capture.barcodes.firstOrNull?.rawValue;
                    if (barcode != null && barcode.isNotEmpty) {
                      _scanned = true;
                      Get.back();
                      controller.addToCartByBarcode(barcode);
                    }
                  },
                ),
              ),
              // Overlay frame
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFF6B35), width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Label atas
              const Positioned(
                top: 16,
                left: 0, right: 0,
                child: Text(
                  'Arahkan ke barcode produk',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              // Tombol close
              Positioned(
                bottom: 16,
                left: 0, right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Batal', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }

// ── Data class ────────────────────────────────────────────────────────────

class _SideNavItem {
  final IconData      icon;
  final String        label;
  final VoidCallback? onTap;
  final bool          selected;
  final LowStockNotificationService? badgeService;
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badgeService,
  });
}
