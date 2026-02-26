import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/product_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/inventory/inventory_service.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({Key? key}) : super(key: key);

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  static const _dark   = Color(0xFF1A1D26);
  static const _accent = Color(0xFFFF6B35);
  static const _green  = Color(0xFF22C55E);
  static const _red    = Color(0xFFEF4444);
  static const _bgGray = Color(0xFFF4F5F7);

  final _storage  = const FlutterSecureStorage();
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  late AuthService _auth;
  late InventoryService _inventory;

  // Form state
  Product? _selectedProduct;
  Map<String, dynamic>? _toBranch;   // branch tujuan
  int _qty = 1;
  String _notes = '';
  bool _isSending = false;

  List<Map<String, dynamic>> _branches = [];
  String _searchQuery = '';
  final _qtyController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _auth      = Get.find<AuthService>();
    _inventory = Get.find<InventoryService>();
    _loadBranches();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _setQty(int newQty) {
    final max = _selectedProduct?.localStock ?? 9999;
    final clamped = newQty.clamp(1, max > 0 ? max : 9999);
    setState(() => _qty = clamped);
    _qtyController.text = '$clamped';
    _qtyController.selection = TextSelection.collapsed(offset: _qtyController.text.length);
  }

  Future<void> _loadBranches() async {
    // Semua branch dari AuthService kecuali branch aktif saat ini
    final currentBranchId = _auth.selectedBranch?.id;
    final all = _auth.branches;
    setState(() {
      _branches = all
          .where((b) => b.id != currentBranchId)
          .map((b) => {'id': b.id, 'name': b.name})
          .toList();
    });
  }

  Future<void> _doTransfer() async {
    if (_selectedProduct == null || _toBranch == null) return;
    if (_qty <= 0) {
      Get.snackbar('Error', 'Jumlah harus lebih dari 0',
          backgroundColor: _red, colorText: Colors.white, snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12));
      return;
    }

    final currentStock = _selectedProduct!.localStock ?? 0;
    if (_qty > currentStock) {
      Get.snackbar('Stok Tidak Cukup',
          'Stok tersedia: $currentStock. Tidak bisa transfer $_qty.',
          backgroundColor: _red, colorText: Colors.white, snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Produk', _selectedProduct!.name),
            _confirmRow('Dari', _auth.selectedBranch?.name ?? '-'),
            _confirmRow('Ke', _toBranch!['name'] as String),
            _confirmRow('Jumlah', '$_qty ${_selectedProduct!.unit}'),
            if (_notes.isNotEmpty) _confirmRow('Catatan', _notes),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/stocks/transfer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'from_branch_id': _auth.selectedBranch?.id,
          'to_branch_id':   _toBranch!['id'],
          'product_id':     _selectedProduct!.id,
          'quantity':       _qty,
          'notes':          _notes.isEmpty ? 'Transfer stok' : _notes,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Update stok lokal (kurangi dari cabang ini)
        final newStock = currentStock - _qty;
        await _inventory.updateStock(
          _selectedProduct!.id!,
          newStock,
          reason: 'Transfer ke ${_toBranch!['name']}',
        );

        Get.snackbar('Transfer Berhasil',
            '$_qty ${_selectedProduct!.unit} ${_selectedProduct!.name} berhasil ditransfer ke ${_toBranch!['name']}',
            backgroundColor: _green, colorText: Colors.white,
            snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4));

        // Reset form
        setState(() {
          _selectedProduct = null;
          _toBranch        = null;
          _qty             = 1;
          _notes           = '';
        });
        _qtyController.text = '1';
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Transfer gagal');
      }
    } catch (e) {
      Get.snackbar('Transfer Gagal', e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: _red, colorText: Colors.white,
          snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12));
    } finally {
      setState(() => _isSending = false);
    }
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70,
              child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          const Text(': ', style: TextStyle(fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFromBranchCard(),
                  const SizedBox(height: 12),
                  _buildProductSelector(),
                  const SizedBox(height: 12),
                  _buildToBranchSelector(),
                  const SizedBox(height: 12),
                  if (_selectedProduct != null) _buildQtyAndNotesCard(),
                  const SizedBox(height: 20),
                  if (_selectedProduct != null && _toBranch != null)
                    _buildTransferButton(),
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                Text('Transfer Stok', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                Text('Pindahkan stok antar cabang', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── From Branch Card ──────────────────────────────────────────────────────

  Widget _buildFromBranchCard() {
    final branch = _auth.selectedBranch;
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cabang Asal (Aktif)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(branch?.name ?? '-',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _dark)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Product Selector ──────────────────────────────────────────────────────

  Widget _buildProductSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilih Produk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showProductPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _bgGray,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectedProduct == null
                        ? Text('Tap untuk pilih produk',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedProduct!.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                              Text('Stok tersedia: ${_selectedProduct!.localStock ?? 0} ${_selectedProduct!.unit}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductPicker() async {
    final products = _inventory.products;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true, fillColor: _bgGray,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              Expanded(
                child: StatefulBuilder(builder: (_, setS) {
                  final filtered = products.where((p) =>
                    p.name.toLowerCase().contains(_searchQuery) ||
                    p.sku.toLowerCase().contains(_searchQuery)
                  ).toList();
                  return ListView.builder(
                    controller: ctrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final stock = p.localStock ?? 0;
                      return ListTile(
                        title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('Stok: $stock ${p.unit}  •  SKU: ${p.sku}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: stock == 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Habis', style: TextStyle(fontSize: 10, color: _red, fontWeight: FontWeight.bold)),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedProduct = p;
                            _qty = 1;
                          });
                          _qtyController.text = '1';
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _searchQuery = '');
  }

  // ── To Branch Selector ────────────────────────────────────────────────────

  Widget _buildToBranchSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cabang Tujuan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 10),
          if (_branches.isEmpty)
            Text('Tidak ada cabang lain', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _branches.map((b) {
                final selected = _toBranch?['id'] == b['id'];
                return GestureDetector(
                  onTap: () => setState(() => _toBranch = b),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? _accent : _bgGray,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? _accent : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded,
                            size: 14, color: selected ? Colors.white : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(b['name'] as String,
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: selected ? Colors.white : _dark,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Qty & Notes ───────────────────────────────────────────────────────────

  Widget _buildQtyAndNotesCard() {
    final maxStock = _selectedProduct?.localStock ?? 0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jumlah Transfer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 10),
          Row(
            children: [
              _roundBtn(Icons.remove, () { if (_qty > 1) _setQty(_qty - 1); }),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) {
                    final val = int.tryParse(v) ?? 1;
                    setState(() => _qty = val.clamp(1, maxStock > 0 ? maxStock : 9999));
                  },
                ),
              ),
              const SizedBox(width: 12),
              _roundBtn(Icons.add, () { _setQty(_qty + 1); }),
              const SizedBox(width: 16),
              Text('Max: $maxStock ${_selectedProduct?.unit ?? ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Catatan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: 'Catatan transfer (opsional)',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              filled: true, fillColor: _bgGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            maxLines: 2,
            onChanged: (v) => _notes = v,
          ),
        ],
      ),
    );
  }

  // ── Transfer Button ───────────────────────────────────────────────────────

  Widget _buildTransferButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : _doTransfer,
        icon: _isSending
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.swap_horiz_rounded),
        label: Text(_isSending ? 'Memproses...' : 'Transfer Sekarang',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _bgGray, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _dark),
      ),
    );
  }
}
