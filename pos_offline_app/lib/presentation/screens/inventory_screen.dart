import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/auth/auth_service.dart';
import '../../services/inventory/inventory_service.dart';
import '../../services/inventory/low_stock_notification_service.dart';
import '../../data/models/product_model.dart';
import '../widgets/connectivity_indicator.dart';
import 'product_form_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all | low | out

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryService = Get.find<InventoryService>();
    final currency = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Get.to(() => const ProductFormScreen());
          inventoryService.loadProducts();
        },
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah Produk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          _buildHeader(inventoryService, isTablet),

          // ── Body ────────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (inventoryService.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                    strokeWidth: 2.5,
                  ),
                );
              }

              final stats = inventoryService.getInventoryStats();
              final allProducts = inventoryService.products;

              // Filter produk
              final filtered = allProducts.where((p) {
                final q = _searchQuery.toLowerCase();
                final matchSearch = q.isEmpty ||
                    p.name.toLowerCase().contains(q) ||
                    p.sku.toLowerCase().contains(q);
                final stock = p.localStock ?? 0;
                final matchFilter = _filterStatus == 'all'
                    ? true
                    : _filterStatus == 'low'
                        ? (stock > 0 && stock <= p.minStock)
                        : stock == 0;
                return matchSearch && matchFilter;
              }).toList();

              final hPad = isTablet ? 24.0 : 20.0;

              return CustomScrollView(
                slivers: [
                  // Stat cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
                      child: _buildStatRow(stats, isTablet),
                    ),
                  ),

                  // Search + filter bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 4),
                      child: _buildSearchFilter(isTablet),
                    ),
                  ),

                  // List header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
                      child: Row(
                        children: [
                          const Text(
                            'Daftar Produk',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1D26),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${filtered.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty state
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(allProducts.isEmpty),
                    )
                  else if (isTablet)
                    // Tablet: 2-column list (bukan grid agar tidak fixed height)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final left  = i * 2;
                            final right = i * 2 + 1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildProductCard(filtered[left], currency, isTablet: true),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: right < filtered.length
                                          ? _buildProductCard(filtered[right], currency, isTablet: true)
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: (filtered.length / 2).ceil(),
                        ),
                      ),
                    )
                  else
                    // Phone: single-column list
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildProductCard(filtered[i], currency),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(InventoryService svc, bool isTablet) {
    final authService = Get.find<AuthService>();
    final branch = authService.selectedBranch;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(isTablet ? 24 : 20, 16, isTablet ? 24 : 16, 16),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      size: 16, color: Color(0xFF1A1D26)),
                ),
              ),
              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manajemen Inventori',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D26),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          branch?.name ?? 'Semua Cabang',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Low Stock Alert button with badge
              Builder(builder: (_) {
                final notifSvc = Get.find<LowStockNotificationService>();
                return GestureDetector(
                  onTap: () => Get.toNamed('/stock-opname'),
                  child: notifSvc.buildBadge(
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.notifications_rounded, size: 18, color: Color(0xFFFF9800)),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),

              // Stock Opname button
              GestureDetector(
                onTap: () => Get.toNamed('/stock-opname'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.fact_check_rounded, size: 18, color: Color(0xFF4CAF50)),
                ),
              ),
              const SizedBox(width: 8),

              // Transfer Stok button
              GestureDetector(
                onTap: () => Get.toNamed('/stock-transfer'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF2196F3)),
                ),
              ),
              const SizedBox(width: 8),

              // Connectivity
              const ConnectivityDot(),
              const SizedBox(width: 8),

              // Refresh dari server
              Obx(() => GestureDetector(
                onTap: svc.isLoading
                    ? null
                    : () async {
                        final auth = Get.find<AuthService>();
                        final ok = await auth.refreshProductsFromServer();
                        Get.snackbar(
                          ok ? 'Berhasil' : 'Gagal',
                          ok
                              ? 'Data produk berhasil diperbarui dari server'
                              : 'Tidak dapat terhubung ke server',
                          snackPosition:   SnackPosition.TOP,
                          backgroundColor: ok
                              ? const Color(0xFF4CAF50)
                              : Colors.orange.shade700,
                          colorText:  Colors.white,
                          margin:     const EdgeInsets.all(12),
                          duration:   const Duration(seconds: 3),
                          borderRadius: 12,
                          icon: Icon(
                            ok
                                ? Icons.cloud_done_rounded
                                : Icons.wifi_off_rounded,
                            color: Colors.white,
                          ),
                        );
                      },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: svc.isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          ),
                    color: svc.isLoading ? const Color(0xFFF7F8FA) : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: svc.isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: svc.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF6B35)),
                        )
                      : const Icon(Icons.cloud_download_rounded,
                          color: Colors.white, size: 18),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── STAT ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatRow(Map<String, dynamic> stats, bool isTablet) {
    final items = [
      _StatItem(
        label: 'Total Produk',
        value: '${stats['totalProducts'] ?? 0}',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF2196F3),
        bg: const Color(0xFFE3F2FD),
      ),
      _StatItem(
        label: 'Total Stok',
        value: '${stats['totalStock'] ?? 0}',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF4CAF50),
        bg: const Color(0xFFE8F5E9),
      ),
      _StatItem(
        label: 'Stok Rendah',
        value: '${stats['lowStockCount'] ?? 0}',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF9800),
        bg: const Color(0xFFFFF3E0),
      ),
      _StatItem(
        label: 'Habis',
        value: '${stats['outOfStockCount'] ?? 0}',
        icon: Icons.remove_shopping_cart_rounded,
        color: const Color(0xFFF44336),
        bg: const Color(0xFFFFEBEE),
      ),
    ];

    return Row(
      children: items
          .map((s) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: items.indexOf(s) < items.length - 1 ? 10 : 0),
                  child: _buildStatCard(s, isTablet: isTablet),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatCard(_StatItem data, {bool isTablet = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 14 : 10, vertical: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: data.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1D26),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(fontSize: isTablet ? 10 : 9, color: Colors.grey[500]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── SEARCH + FILTER ───────────────────────────────────────────────────────

  Widget _buildSearchFilter([bool isTablet = false]) {
    return Column(
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari produk, SKU...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey[400], size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: Colors.grey[400], size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        Row(
          children: [
            _filterChip('Semua', 'all', Icons.apps_rounded),
            const SizedBox(width: 8),
            _filterChip('Stok Rendah', 'low', Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _filterChip('Habis', 'out', Icons.remove_shopping_cart_rounded),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF6B35)
                : const Color(0xFFEEEEEE),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PRODUCT CARD ──────────────────────────────────────────────────────────

  Widget _buildProductCard(Product product, NumberFormat currency, {bool isTablet = false}) {
    final svc = Get.find<InventoryService>();
    final stock = product.localStock ?? 0;
    final isOut = stock == 0;
    final isLow = !isOut && stock <= product.minStock;

    final Color stockColor = isOut
        ? const Color(0xFFF44336)
        : isLow
            ? const Color(0xFFFF9800)
            : const Color(0xFF4CAF50);

    final Color stockBg = isOut
        ? const Color(0xFFFFEBEE)
        : isLow
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE8F5E9);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (ctx, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
      margin: isTablet ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: stockColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            childrenPadding: EdgeInsets.zero,
            leading: _buildProductLeading(product, stockBg, stockColor, isOut, isLow),
            title: Text(
              product.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D26),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'SKU: ${product.sku}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stock badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: stockBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: stockColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$stock',
                    style: TextStyle(
                      color: stockColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Pending sync dot
                if (!product.isSynced)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9800),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            // ── Detail panel ────────────────────────────────────
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    // Row harga & cost
                    Row(
                      children: [
                        Expanded(
                          child: _detailTile(
                            icon: Icons.sell_rounded,
                            iconColor: const Color(0xFF4CAF50),
                            label: 'Harga Jual',
                            value: currency.format(product.price),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _detailTile(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFF2196F3),
                            label: 'Harga Modal',
                            value: currency.format(product.cost),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row stok & unit
                    Row(
                      children: [
                        Expanded(
                          child: _detailTile(
                            icon: Icons.inventory_rounded,
                            iconColor: stockColor,
                            label: 'Stok Saat Ini',
                            value: '$stock ${product.unit}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _detailTile(
                            icon: Icons.move_to_inbox_rounded,
                            iconColor: const Color(0xFFFF9800),
                            label: 'Min. Stok',
                            value: '${product.minStock} ${product.unit}',
                          ),
                        ),
                      ],
                    ),

                    // Deskripsi
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deskripsi',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(product.description!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1A1D26))),
                          ],
                        ),
                      ),
                    ],

                    // Pending sync banner
                    if (!product.isSynced) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFF9800)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 14, color: Color(0xFFFF9800)),
                            SizedBox(width: 8),
                            Text(
                              'Menunggu sinkronisasi ke server',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons: Edit & Hapus
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Edit
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await Get.to(
                                () => ProductFormScreen(product: product),
                              );
                              svc.loadProducts();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF2196F3)
                                        .withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_rounded,
                                      size: 15, color: Color(0xFF2196F3)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Hapus
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _confirmDelete(product, svc),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFF44336)
                                        .withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_rounded,
                                      size: 15, color: Color(0xFFF44336)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Hapus',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF44336),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tombol Ubah Stok — hanya untuk owner
                    Builder(builder: (_) {
                      final user = Get.find<AuthService>().currentUser;
                      if (user == null || !user.isOwner) return const SizedBox.shrink();
                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _showUpdateStockDialog(product, svc),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE7F6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tune_rounded,
                                      size: 15, color: Color(0xFF7C3AED)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Ubah Stok',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ), // end TweenAnimationBuilder child Container
    ); // end TweenAnimationBuilder
  }

  // ── PRODUCT LEADING (gambar / icon) ───────────────────────────────────────

  Widget _buildProductLeading(
    Product product,
    Color stockBg,
    Color stockColor,
    bool isOut,
    bool isLow,
  ) {
    final imagePath = product.image;
    if (imagePath != null && imagePath.isNotEmpty) {
      // URL
      if (imagePath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.network(
            imagePath,
            width: 44, height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _stockIcon(stockBg, stockColor, isOut, isLow),
          ),
        );
      }
      // File lokal
      final file = File(imagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.file(file,
              width: 44, height: 44, fit: BoxFit.cover),
        );
      }
    }
    return _stockIcon(stockBg, stockColor, isOut, isLow);
  }

  Widget _stockIcon(
      Color stockBg, Color stockColor, bool isOut, bool isLow) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: stockBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        isOut
            ? Icons.remove_shopping_cart_rounded
            : isLow
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_rounded,
        color: stockColor,
        size: 20,
      ),
    );
  }

  // ── UPDATE STOCK DIALOG ───────────────────────────────────────────────────

  void _showUpdateStockDialog(Product product, InventoryService svc) {
    final currentStock = product.localStock ?? 0;
    final stockCtrl = TextEditingController(text: '$currentStock');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ubah Stok',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info produk
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        size: 16, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Stok saat ini: $currentStock ${product.unit}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Input stok baru
            Text(
              'Jumlah Stok Baru',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Masukkan jumlah stok',
                suffixText: product.unit,
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF7C3AED), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Catatan
            Text(
              'Catatan (opsional)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                hintText: 'Misal: stok opname, tambah dari supplier',
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF7C3AED), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Get.back();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      stockCtrl.dispose();
                      notesCtrl.dispose();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Batal',
                      style: TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final newStock = int.tryParse(stockCtrl.text.trim());
                    if (newStock == null || newStock < 0) {
                      Get.snackbar(
                        'Input Tidak Valid',
                        'Masukkan angka stok yang benar',
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: Colors.red.shade600,
                        colorText: Colors.white,
                      );
                      return;
                    }
                    final notes = notesCtrl.text.trim();
                    Get.back();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      stockCtrl.dispose();
                      notesCtrl.dispose();
                    });
                    await svc.updateStock(
                      product.id!,
                      newStock,
                      reason: notes.isEmpty ? 'Penyesuaian stok manual' : notes,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CONFIRM DELETE ────────────────────────────────────────────────────────

  void _confirmDelete(Product product, InventoryService svc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Produk',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_rounded,
                  color: Color(0xFFF44336), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Yakin ingin menghapus produk\n"${product.name}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Produk akan dinonaktifkan dan akan disinkronkan ke server.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(
                        color: Color(0xFFDDDDDD)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Batal',
                      style: TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    svc.deleteProduct(product.id!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF44336),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Hapus',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D26)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool noProducts) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.07),
                ),
              ),
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                ),
              ),
              const Icon(Icons.inventory_2_outlined,
                  size: 30, color: Color(0xFFFF6B35)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            noProducts
                ? 'Belum ada produk'
                : 'Tidak ada hasil',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noProducts
                ? 'Belum ada produk. Tambah produk baru sekarang!'
                : 'Coba ubah kata kunci atau filter pencarian',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (noProducts) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final svc = Get.find<InventoryService>();
                await Get.to(() => const ProductFormScreen());
                svc.loadProducts();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35)
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Tambah Produk Pertama',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Data model lokal ───────────────────────────────────────────────────────

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });
}
