import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/product_model.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/supplier_model.dart';
import '../../services/inventory/inventory_service.dart';
import '../../services/purchase/purchase_service.dart';
import '../../services/supplier/supplier_service.dart';

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _currency = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _formKey = GlobalKey<FormState>();

  late final PurchaseService  _purchaseSvc;
  late final SupplierService  _supplierSvc;
  late final InventoryService _invSvc;

  // Form state
  Supplier?          _selectedSupplier;
  DateTime           _purchaseDate = DateTime.now();
  final List<_CartItem> _cartItems  = [];
  final Map<int, TextEditingController> _qtyControllers = {};
  final _notesCtrl = TextEditingController();
  double _discount = 0;
  double _tax      = 0;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _purchaseSvc = Get.find<PurchaseService>();
    _supplierSvc = Get.find<SupplierService>();
    _invSvc      = Get.find<InventoryService>();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _subtotal =>
      _cartItems.fold(0, (sum, i) => sum + i.subtotal);

  double get _total => _subtotal - _discount + _tax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('PO Baru',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E2235),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize:   15),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Supplier ─────────────────────────────────────────
              _sectionCard(
                title: 'Supplier',
                icon:  Icons.business_rounded,
                child: Obx(() {
                  final suppliers = _supplierSvc.suppliers;
                  return DropdownButtonFormField<Supplier>(
                    value: _selectedSupplier,
                    decoration: _inputDecoration('Pilih Supplier (opsional)'),
                    items: [
                      const DropdownMenuItem<Supplier>(
                        value: null,
                        child: Text('Tanpa Supplier'),
                      ),
                      ...suppliers.map((s) => DropdownMenuItem<Supplier>(
                            value: s,
                            child: Text(s.displayName,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedSupplier = v),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // ── Tanggal Pembelian ─────────────────────────────────
              _sectionCard(
                title: 'Tanggal Pembelian',
                icon:  Icons.calendar_today_rounded,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border:       Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded,
                            color: Colors.grey[400], size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('dd MMMM yyyy', 'id_ID')
                              .format(_purchaseDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Produk ───────────────────────────────────────────
              _sectionCard(
                title: 'Produk',
                icon:  Icons.inventory_2_rounded,
                trailing: TextButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Tambah'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    padding: EdgeInsets.zero,
                  ),
                ),
                child: _cartItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.add_shopping_cart_rounded,
                                  size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Belum ada produk',
                                  style: TextStyle(color: Colors.grey[400])),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _cartItems.asMap().entries.map((entry) {
                          final idx  = entry.key;
                          final item = entry.value;
                          return _buildCartItemRow(idx, item);
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),

              // ── Biaya Tambahan ────────────────────────────────────
              _sectionCard(
                title: 'Biaya & Potongan',
                icon:  Icons.calculate_rounded,
                child: Column(
                  children: [
                    _buildNumberField(
                      label:      'Diskon (Rp)',
                      initialVal: _discount,
                      onChanged:  (v) => setState(() => _discount = v),
                    ),
                    const SizedBox(height: 10),
                    _buildNumberField(
                      label:      'Pajak (Rp)',
                      initialVal: _tax,
                      onChanged:  (v) => setState(() => _tax = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Catatan ─────────────────────────────────────────
              _sectionCard(
                title: 'Catatan',
                icon:  Icons.notes_rounded,
                child: TextFormField(
                  controller:  _notesCtrl,
                  maxLines:    3,
                  decoration:  _inputDecoration('Catatan (opsional)'),
                ),
              ),
              const SizedBox(height: 12),

              // ── Ringkasan Total ──────────────────────────────────
              _buildSummary(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cart item row ────────────────────────────────────────────────────────

  Widget _buildCartItemRow(int idx, _CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Product name & delete button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1D26),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item.productId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.red.shade400, size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _qtyControllers.remove(item.productId);
                      _cartItems.removeAt(idx);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Input row: Price & Quantity
          Row(
            children: [
              // Harga Beli
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Harga Beli',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: item.cost.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF7C3AED),
                      ),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F7FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) {
                        final val = double.tryParse(v) ?? 0;
                        setState(() {
                          _cartItems[idx] = _CartItem(
                            productId:   item.productId,
                            productName: item.productName,
                            cost:        val,
                            quantity:    item.quantity,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Quantity stepper dengan input manual
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE8E4F5)),
                      ),
                      child: Row(
                        children: [
                          // Tombol Minus
                          InkWell(
                            onTap: item.quantity > 1
                                ? () {
                                    final newQty = item.quantity - 1;
                                    setState(() {
                                      _cartItems[idx] = _CartItem(
                                        productId:   item.productId,
                                        productName: item.productName,
                                        cost:        item.cost,
                                        quantity:    newQty,
                                      );
                                      // Update controller dengan proper TextEditingValue
                                      final controller = _qtyControllers[item.productId]!;
                                      controller.value = TextEditingValue(
                                        text: newQty.toString(),
                                        selection: TextSelection.collapsed(offset: newQty.toString().length),
                                      );
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: item.quantity > 1
                                    ? const LinearGradient(
                                        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: item.quantity > 1 ? null : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: item.quantity > 1
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.remove_rounded,
                                size: 18,
                                color: item.quantity > 1
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Input Field
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: TextFormField(
                                controller: _qtyControllers[item.productId],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1A1D26),
                                ),
                                onChanged: (v) {
                                  final qty = int.tryParse(v) ?? 0;
                                  if (qty > 0) {
                                    setState(() {
                                      _cartItems[idx] = _CartItem(
                                        productId:   item.productId,
                                        productName: item.productName,
                                        cost:        item.cost,
                                        quantity:    qty,
                                      );
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Tombol Plus
                          InkWell(
                            onTap: () {
                              final newQty = item.quantity + 1;
                              setState(() {
                                _cartItems[idx] = _CartItem(
                                  productId:   item.productId,
                                  productName: item.productName,
                                  cost:        item.cost,
                                  quantity:    newQty,
                                );
                                // Update controller dengan proper TextEditingValue
                                final controller = _qtyControllers[item.productId]!;
                                controller.value = TextEditingValue(
                                  text: newQty.toString(),
                                  selection: TextSelection.collapsed(offset: newQty.toString().length),
                                );
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Subtotal
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.05),
                  const Color(0xFF7C3AED).withValues(alpha: 0.1),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calculate_rounded,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currency.format(item.subtotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF2D3142)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2235).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Ringkasan Pesanan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRowDark('Subtotal', _currency.format(_subtotal)),
          if (_discount > 0)
            _summaryRowDark('Diskon', '- ${_currency.format(_discount)}', isNegative: true),
          if (_tax > 0)
            _summaryRowDark('Pajak', '+ ${_currency.format(_tax)}', isPositive: true),
          const Divider(height: 24, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.white70,
                      )),
                  SizedBox(height: 2),
                  Text('Pembelian',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      )),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _currency.format(_total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRowDark(String label, String value, {bool isNegative = false, bool isPositive = false}) {
    Color valueColor = isNegative 
        ? Colors.greenAccent.shade400 
        : isPositive 
            ? Colors.orangeAccent.shade400 
            : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              )),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              )),
        ],
      ),
    );
  }

  // ── Add Product Dialog ───────────────────────────────────────────────────

  void _showAddProductDialog() {
    final products   = _invSvc.products;
    final searchCtrl = TextEditingController();
    List<Product> filtered = List.from(products);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize:     0.95,
          minChildSize:     0.5,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText:     'Cari produk...',
                      prefixIcon:   const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (q) {
                      setModal(() {
                        final lq = q.toLowerCase();
                        filtered = products
                            .where((p) =>
                                p.name.toLowerCase().contains(lq) ||
                                p.sku.toLowerCase().contains(lq))
                            .toList();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller:  scrollCtrl,
                    itemCount:   filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final alreadyAdded = _cartItems
                          .any((c) => c.productId == p.id);
                      return ListTile(
                        title: Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text('SKU: ${p.sku} | Stok: ${p.localStock ?? 0}'),
                        trailing: alreadyAdded
                            ? const Chip(
                                label: Text('Sudah ada'),
                                backgroundColor: Color(0xFFEDE7F6),
                              )
                            : const Icon(Icons.add_circle_rounded,
                                color: Color(0xFF7C3AED)),
                        onTap: alreadyAdded
                            ? null
                            : () {
                                setState(() {
                                  final newItem = _CartItem(
                                    productId:   p.id!,
                                    productName: p.name,
                                    cost:        p.cost,
                                    quantity:    1,
                                  );
                                  _cartItems.add(newItem);
                                  _qtyControllers[newItem.productId] = 
                                      TextEditingController(text: '1');
                                });
                                Get.back();
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _purchaseDate,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    if (_cartItems.isEmpty) {
      Get.snackbar(
        'Peringatan',
        'Tambahkan minimal satu produk',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText:       Colors.white,
      );
      return;
    }

    setState(() => _isSaving = true);

    final items = _cartItems
        .map((c) => PurchaseItem(
              productId:   c.productId,
              productName: c.productName,
              cost:        c.cost,
              quantity:    c.quantity,
              discount:    0,
              subtotal:    c.subtotal,
            ))
        .toList();

    final ok = await _purchaseSvc.createPurchase(
      supplierId:    _selectedSupplier?.id,
      supplierName:  _selectedSupplier?.displayName ?? '',
      purchaseDate:  DateFormat('yyyy-MM-dd').format(_purchaseDate),
      items:         items,
      discount:      _discount,
      tax:           _tax,
      notes:         _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
    );

    setState(() => _isSaving = false);

    if (ok) {
      // Refresh product list agar local_stock update
      await Get.find<InventoryService>().loadProducts();

      // Tampilkan dialog sukses lalu redirect ke list pembelian
      await Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 52),
                    SizedBox(height: 10),
                    Text(
                      'PO Tersimpan!',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Pembelian berhasil dicatat dan stok produk telah diperbarui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      // Setelah dialog ditutup, kembali ke list pembelian
      Get.back();
    }
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1D26))),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required double initialVal,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      initialValue: initialVal > 0 ? initialVal.toStringAsFixed(0) : '',
      keyboardType: TextInputType.number,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: _inputDecoration(label),
      onChanged:    (v) => onChanged(double.tryParse(v) ?? 0),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade500,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F7FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Simple cart item model ───────────────────────────────────────────────────

class _CartItem {
  final int    productId;
  final String productName;
  final double cost;
  final int    quantity;

  const _CartItem({
    required this.productId,
    required this.productName,
    required this.cost,
    required this.quantity,
  });

  double get subtotal => cost * quantity;
}
