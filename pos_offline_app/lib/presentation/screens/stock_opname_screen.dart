import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/inventory/stock_opname_service.dart';

class StockOpnameScreen extends StatefulWidget {
  const StockOpnameScreen({Key? key}) : super(key: key);

  @override
  State<StockOpnameScreen> createState() => _StockOpnameScreenState();
}

class _StockOpnameScreenState extends State<StockOpnameScreen>
    with SingleTickerProviderStateMixin {
  late StockOpnameService _svc;
  late TabController _tabCtrl;

  final _searchCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _searchQuery = '';

  static const _dark   = Color(0xFF1A1D26);
  static const _accent = Color(0xFFFF6B35);
  static const _green  = Color(0xFF22C55E);
  static const _red    = Color(0xFFEF4444);
  static const _bgGray = Color(0xFFF4F5F7);

  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (!Get.isRegistered<StockOpnameService>()) {
      Get.put(StockOpnameService());
    }
    _svc = Get.find<StockOpnameService>();
    _svc.loadHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Mulai opname baru ─────────────────────────────────────────────────────

  Future<void> _startNewOpname() async {
    await _svc.startNewOpname();
    _tabCtrl.animateTo(0);
  }

  // ── Simpan opname ─────────────────────────────────────────────────────────

  Future<void> _confirmSave() async {
    final varCount = _svc.totalVarianceItems;
    final confirm  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Simpan Stock Opname?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total produk: ${_svc.opnameItems.length}'),
            if (varCount > 0)
              Text('Produk dengan selisih: $varCount',
                  style: const TextStyle(color: _red, fontWeight: FontWeight.bold)),
            if (varCount == 0)
              const Text('Tidak ada selisih stok.',
                  style: TextStyle(color: _green)),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                hintText: 'Catatan (opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
            child: const Text('Simpan & Terapkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _svc.saveOpname(notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim());
      _notesCtrl.clear();
      if (ok) {
        Get.snackbar('Berhasil', 'Stock opname berhasil disimpan & stok diperbarui',
            backgroundColor: _green, colorText: Colors.white,
            snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12));
        _tabCtrl.animateTo(1); // Pindah ke tab Riwayat
      } else {
        Get.snackbar('Gagal', 'Terjadi kesalahan saat menyimpan opname',
            backgroundColor: _red, colorText: Colors.white,
            snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildOpnameTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Opname',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                Text('Hitung & rekonsiliasi stok fisik',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Obx(() => _svc.opnameItems.isEmpty
              ? TextButton.icon(
                  onPressed: _startNewOpname,
                  icon: const Icon(Icons.add_rounded, color: _accent, size: 18),
                  label: const Text('Mulai', style: TextStyle(color: _accent, fontWeight: FontWeight.bold)),
                )
              : TextButton.icon(
                  onPressed: _confirmSave,
                  icon: const Icon(Icons.save_rounded, color: _green, size: 18),
                  label: const Text('Simpan', style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
                )),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _accent,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _accent,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Opname Sekarang'),
          Tab(text: 'Riwayat'),
        ],
      ),
    );
  }

  // ── Tab: Opname Sekarang ──────────────────────────────────────────────────

  Widget _buildOpnameTab() {
    return Obx(() {
      if (_svc.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: _accent));
      }
      if (_svc.opnameItems.isEmpty) {
        return _buildEmptyOpname();
      }
      return _buildOpnameList();
    });
  }

  Widget _buildEmptyOpname() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Belum ada opname aktif', style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Tekan "Mulai" untuk memulai penghitungan stok',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startNewOpname,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Mulai Opname'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpnameList() {
    return Column(
      children: [
        // Search + summary bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 18),
                    filled: true,
                    fillColor: _bgGray,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              Obx(() {
                final v = _svc.totalVarianceItems;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: v > 0 ? _red.withValues(alpha: 0.1) : _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$v selisih',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: v > 0 ? _red : _green)),
                );
              }),
            ],
          ),
        ),
        // List produk
        Expanded(
          child: Obx(() {
            final items = _svc.opnameItems.where((i) {
              if (_searchQuery.isEmpty) return true;
              return i.product.name.toLowerCase().contains(_searchQuery) ||
                  i.product.sku.toLowerCase().contains(_searchQuery);
            }).toList();

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, idx) => _buildOpnameItemCard(items[idx]),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOpnameItemCard(OpnameItem item) {
    final hasVar = item.hasVariance;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasVar ? (item.variance > 0 ? _green : _red).withValues(alpha: 0.4) : Colors.transparent,
          width: hasVar ? 1.5 : 0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Info produk
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
                    overflow: TextOverflow.ellipsis),
                Text(item.product.sku,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _qtyChip('Sistem', item.systemQty, Colors.grey.shade600),
                    const SizedBox(width: 6),
                    if (hasVar)
                      _qtyChip(
                        item.variance > 0 ? '+${item.variance}' : '${item.variance}',
                        null,
                        item.variance > 0 ? _green : _red,
                        isVariance: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Input hitung fisik
          Column(
            children: [
              const Text('Hitung', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  _roundBtn(Icons.remove, () {
                    if (item.countedQty > 0) {
                      _svc.updateCountedQty(item.product.id!, item.countedQty - 1);
                    }
                  }),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 48,
                    child: TextFormField(
                      initialValue: item.countedQty.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (v) {
                        final qty = int.tryParse(v) ?? item.countedQty;
                        _svc.updateCountedQty(item.product.id!, qty);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  _roundBtn(Icons.add, () {
                    _svc.updateCountedQty(item.product.id!, item.countedQty + 1);
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyChip(String label, int? value, Color color, {bool isVariance = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isVariance ? label : '$label: $value',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _bgGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _dark),
      ),
    );
  }

  // ── Tab: Riwayat ──────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return Obx(() {
      if (_svc.history.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Belum ada riwayat opname',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _svc.history.length,
        itemBuilder: (_, i) => _buildHistoryCard(_svc.history[i]),
      );
    });
  }

  Widget _buildHistoryCard(StockOpnameSummary s) {
    final hasVar = s.itemsWithVariance > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasVar ? _red.withValues(alpha: 0.1) : _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasVar ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: hasVar ? _red : _green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.opnameNumber,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
                Text(s.opnameDate,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${s.totalItems} produk',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    if (hasVar) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${s.itemsWithVariance} selisih',
                            style: const TextStyle(fontSize: 10, color: _red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s.status.toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _green)),
          ),
        ],
      ),
    );
  }
}
