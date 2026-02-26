import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/purchase_model.dart';
import '../../services/purchase/purchase_service.dart';
import 'purchase_form_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  late final PurchaseService _svc;
  final _currency = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // ── Filter state ──────────────────────────────────────────────
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  String?   _filterSupplier; // null = semua

  @override
  void initState() {
    super.initState();
    _svc = Get.find<PurchaseService>();
    _svc.loadPurchases();
  }

  // ── Apply filter ──────────────────────────────────────────────
  List<Purchase> _filtered(List<Purchase> all) {
    return all.where((p) {
      // Filter supplier
      if (_filterSupplier != null) {
        final name = p.supplierName ?? '';
        if (name != _filterSupplier) return false;
      }
      // Filter tanggal
      try {
        final dt = DateTime.parse(p.purchaseDate);
        if (_filterDateFrom != null && dt.isBefore(_filterDateFrom!)) {
          return false;
        }
        if (_filterDateTo != null) {
          final toEnd = DateTime(
              _filterDateTo!.year, _filterDateTo!.month, _filterDateTo!.day,
              23, 59, 59);
          if (dt.isAfter(toEnd)) return false;
        }
      } catch (_) {}
      return true;
    }).toList();
  }

  bool get _hasFilter =>
      _filterDateFrom != null ||
      _filterDateTo != null ||
      _filterSupplier != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Pembelian (PO)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E2235),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _svc.loadPurchases,
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Get.to(() => const PurchaseFormScreen());
            _svc.loadPurchases();
          },
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('PO Baru',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
        ),
      ),
      body: Obx(() {
        if (_svc.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final all      = _svc.purchases;
        final list     = _filtered(all);
        final suppliers = all
            .map((p) => p.supplierName ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        if (all.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: _svc.loadPurchases,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Filter bar ──────────────────────────────────
                    _buildFilterBar(suppliers),
                    const SizedBox(height: 12),

                    // ── Summary card (hanya tampil jika ada filter) ─
                    if (_hasFilter) ...[
                      _buildSummaryCard(list),
                      const SizedBox(height: 12),
                    ],

                    // ── Tabel ───────────────────────────────────────
                    if (list.isEmpty)
                      _buildFilterEmpty()
                    else
                      Container(
                        width: constraints.maxWidth - 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(0.8),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(2.2),
                              3: FlexColumnWidth(2.8),
                              4: FlexColumnWidth(0.8),
                              5: FlexColumnWidth(2.2),
                              6: FlexColumnWidth(1.8),
                              7: FlexColumnWidth(1.4),
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                  color: Colors.grey.shade100, width: 1),
                            ),
                            children: [
                              // Header
                              TableRow(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                children: [
                                  _th('No'),
                                  _th('Tanggal'),
                                  _th('No. PO'),
                                  _th('Supplier'),
                                  _th('Item', center: true),
                                  _th('Total', center: true),
                                  _th('Status', center: true),
                                  _th('Sync', center: true),
                                ],
                              ),
                              // Data rows
                              ...list.asMap().entries.map((entry) {
                                final i      = entry.key;
                                final p      = entry.value;
                                final isEven = i % 2 == 0;
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: isEven
                                        ? Colors.white
                                        : const Color(0xFFFFFBF7),
                                  ),
                                  children: [
                                    _tdTap(p,
                                        child: Text('${i + 1}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[400]))),
                                    _tdTap(p,
                                        child: Text(_formatDate(p.purchaseDate),
                                            style: const TextStyle(fontSize: 11))),
                                    _tdTap(p,
                                        child: Text(
                                          p.purchaseNumber ?? 'PO-LOCAL',
                                          style: const TextStyle(
                                            fontSize:   11,
                                            fontWeight: FontWeight.w600,
                                            color:      Color(0xFF1A1D26),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                    _tdTap(p,
                                        child: Text(
                                          p.supplierName?.isNotEmpty == true
                                              ? p.supplierName!
                                              : 'Tanpa Supplier',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        )),
                                    _tdTap(p,
                                        center: true,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEDD5),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${p.items?.length ?? 0}',
                                            style: const TextStyle(
                                              fontSize:   10,
                                              fontWeight: FontWeight.bold,
                                              color:      Color(0xFFF97316),
                                            ),
                                          ),
                                        )),
                                    _tdTap(p,
                                        center: true,
                                        child: Text(
                                          _currency.format(p.total),
                                          style: const TextStyle(
                                            fontSize:   11,
                                            fontWeight: FontWeight.bold,
                                            color:      Color(0xFFF97316),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                    _tdTap(p,
                                        center: true,
                                        child: _StatusBadge(status: p.status)),
                                    _tdTap(p,
                                        center: true,
                                        child: _SyncBadge(isSynced: p.isSynced)),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar(List<String> suppliers) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.filter_list_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text('Filter',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1D26))),
              const Spacer(),
              if (_hasFilter)
                InkWell(
                  onTap: () => setState(() {
                    _filterDateFrom = null;
                    _filterDateTo   = null;
                    _filterSupplier = null;
                  }),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 12, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text('Reset',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Baris filter
          Row(
            children: [
              // Dari tanggal
              Expanded(
                child: _dateField(
                  label: 'Dari',
                  value: _filterDateFrom,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDateFrom ?? DateTime.now(),
                      firstDate:   DateTime(2020),
                      lastDate:    DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _filterDateFrom = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Sampai tanggal
              Expanded(
                child: _dateField(
                  label: 'Sampai',
                  value: _filterDateTo,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDateTo ?? DateTime.now(),
                      firstDate:   DateTime(2020),
                      lastDate:    DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _filterDateTo = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Supplier dropdown
              Expanded(
                flex: 2,
                child: _supplierDropdown(suppliers),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final fmt = DateFormat('dd/MM/yy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: value != null
              ? const Color(0xFFFFFBF7)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null
                ? const Color(0xFFF97316)
                : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 14,
                color: value != null
                    ? const Color(0xFFF97316)
                    : Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? fmt.format(value) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: value != null
                      ? const Color(0xFFF97316)
                      : Colors.grey.shade500,
                  fontWeight: value != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supplierDropdown(List<String> suppliers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _filterSupplier != null
            ? const Color(0xFFFFFBF7)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _filterSupplier != null
              ? const Color(0xFFF97316)
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value:     _filterSupplier,
          isExpanded: true,
          isDense:    true,
          icon: Icon(Icons.expand_more_rounded,
              size: 16,
              color: _filterSupplier != null
                  ? const Color(0xFFF97316)
                  : Colors.grey.shade400),
          style: TextStyle(
            fontSize: 12,
            color: _filterSupplier != null
                ? const Color(0xFFF97316)
                : Colors.grey.shade600,
            fontWeight: _filterSupplier != null
                ? FontWeight.w600
                : FontWeight.normal,
          ),
          hint: Text('Semua Supplier',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Semua Supplier',
                  style: TextStyle(fontSize: 12)),
            ),
            ...suppliers.map((s) => DropdownMenuItem<String?>(
                  value: s,
                  child: Text(s,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (v) => setState(() => _filterSupplier = v),
        ),
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(List<Purchase> list) {
    final grandTotal    = list.fold<double>(0, (s, p) => s + p.total);
    final totalItems    = list.fold<int>(0, (s, p) => s + (p.items?.length ?? 0));
    final totalPO       = list.length;
    final totalDiscount = list.fold<double>(0, (s, p) => s + p.discount);
    final totalTax      = list.fold<double>(0, (s, p) => s + p.tax);

    String rangeLabel = '';
    if (_filterDateFrom != null || _filterDateTo != null) {
      final fmt = DateFormat('dd MMM yyyy', 'id_ID');
      if (_filterDateFrom != null && _filterDateTo != null) {
        rangeLabel =
            '${fmt.format(_filterDateFrom!)} – ${fmt.format(_filterDateTo!)}';
      } else if (_filterDateFrom != null) {
        rangeLabel = 'Dari ${fmt.format(_filterDateFrom!)}';
      } else {
        rangeLabel = 'Sampai ${fmt.format(_filterDateTo!)}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _filterSupplier != null
                          ? 'Ringkasan: $_filterSupplier'
                          : 'Ringkasan Filter',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.bold),
                    ),
                    if (rangeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(rangeLabel,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Total pembelian besar
          Text(
            _currency.format(grandTotal),
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text('Total Pembelian',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12)),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _summaryChip(Icons.receipt_long_rounded,
                  '$totalPO PO', Colors.white),
              const SizedBox(width: 8),
              _summaryChip(Icons.inventory_2_rounded,
                  '$totalItems Item', Colors.white),
              if (totalDiscount > 0) ...[
                const SizedBox(width: 8),
                _summaryChip(Icons.discount_rounded,
                    '- ${_currency.format(totalDiscount)}',
                    Colors.greenAccent.shade200),
              ],
              if (totalTax > 0) ...[
                const SizedBox(width: 8),
                _summaryChip(Icons.percent_rounded,
                    '+ ${_currency.format(totalTax)}',
                    Colors.orangeAccent.shade200),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize:   11,
                  color:      color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Empty filter state ────────────────────────────────────────────────────

  Widget _buildFilterEmpty() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 40, color: const Color(0xFFF97316)),
            ),
            const SizedBox(height: 16),
            Text('Tidak ada data dengan filter ini',
                style: TextStyle(
                    color:    Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Coba ubah atau reset filter Anda',
                style: TextStyle(
                    color:    Colors.grey.shade400,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── PO Card ───────────────────────────────────────────────────────────────

  Widget _buildPOCard(Purchase purchase, int index) {
    return InkWell(
      onTap: () => _showDetail(purchase),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            // Header: PO Number & Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index.toString().padLeft(3, '0')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              purchase.purchaseNumber ?? 'PO-LOCAL',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1D26),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(purchase.purchaseDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _StatusBadge(status: purchase.status),
                    const SizedBox(height: 4),
                    _SyncBadge(isSynced: purchase.isSynced),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Supplier & Items
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              purchase.supplierName?.isNotEmpty == true
                                  ? purchase.supplierName!
                                  : 'Tanpa Supplier',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${purchase.items?.length ?? 0} Item',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Total
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currency.format(purchase.total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                size: 64, color: Color(0xFFF97316)),
          ),
          const SizedBox(height: 24),
          const Text('Belum ada pembelian',
              style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                  color:      Color(0xFF1A1D26))),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text('Tap "+ PO Baru" untuk mencatat pembelian dari supplier',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────

  void _showDetail(Purchase purchase) {
    final currency   = _currency;
    final isCancelled = purchase.status == 'cancelled';

    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize:     0.95,
        minChildSize:     0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded,
                        color: isCancelled
                            ? Colors.grey
                            : const Color(0xFF7C3AED)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            purchase.purchaseNumber ?? 'Detail Pembelian',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (isCancelled)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.red.shade200),
                              ),
                              child: Text('Dibatalkan',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color:    Colors.red.shade600,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _detailRow('Supplier', purchase.supplierName ?? '-'),
                    _detailRow('Tanggal', _formatDate(purchase.purchaseDate)),
                    _detailRow('Status', _statusLabel(purchase.status)),
                    _detailRow('Sync', purchase.isSynced ? 'Sudah sync' : 'Belum sync'),
                    if (purchase.notes?.isNotEmpty == true)
                      _detailRow('Catatan', purchase.notes!),
                    const SizedBox(height: 16),
                    const Text('Item Produk',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (purchase.items != null)
                      ...purchase.items!.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? Colors.grey.shade50
                                  : const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isCancelled
                                                  ? Colors.grey
                                                  : null,
                                              decoration: isCancelled
                                                  ? TextDecoration.lineThrough
                                                  : null)),
                                      Text(
                                        '${item.quantity} × ${currency.format(item.cost)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(currency.format(item.subtotal),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCancelled
                                            ? Colors.grey
                                            : const Color(0xFF7C3AED))),
                              ],
                            ),
                          )),
                    const Divider(height: 24),
                    _detailRow('Subtotal', currency.format(purchase.subtotal)),
                    if (purchase.discount > 0)
                      _detailRow('Diskon',
                          '- ${currency.format(purchase.discount)}'),
                    if (purchase.tax > 0)
                      _detailRow(
                          'Pajak', '+ ${currency.format(purchase.tax)}'),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(currency.format(purchase.total),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isCancelled
                                    ? Colors.grey
                                    : const Color(0xFF7C3AED))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Tombol Cancel ────────────────────────────────
                    if (!isCancelled)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmCancel(purchase),
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.red, size: 18),
                          label: const Text('Batalkan PO',
                              style: TextStyle(
                                  color:      Colors.red,
                                  fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side:   const BorderSide(color: Colors.red),
                            shape:  RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (isCancelled)
                      Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:        Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block_rounded,
                                size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text('PO ini telah dibatalkan',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(Purchase purchase) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Batalkan PO?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PO ${purchase.purchaseNumber ?? ''} akan dibatalkan.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Stok produk yang sudah ditambahkan akan dikembalikan ke kondisi sebelumnya.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Tidak',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      Get.back(); // tutup bottom sheet
      await _svc.cancelPurchase(purchase);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _th(String label, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        label,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          color:      Colors.white,
          fontWeight: FontWeight.bold,
          fontSize:   11,
        ),
      ),
    );
  }

  Widget _tdTap(Purchase p, {required Widget child, bool center = false}) {
    return GestureDetector(
      onTap: () => _showDetail(p),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          const Text(': '),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'received':  return 'Diterima';
      case 'pending':   return 'Pending';
      case 'cancelled': return 'Dibatalkan';
      default:          return status;
    }
  }
}

// ── Badge widgets ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'received':
        color = const Color(0xFF4CAF50); label = 'Diterima'; break;
      case 'pending':
        color = Colors.orange;           label = 'Pending';  break;
      case 'cancelled':
        color = Colors.red;              label = 'Dibatalkan'; break;
      default:
        color = Colors.grey;             label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final bool isSynced;
  const _SyncBadge({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
          size:  14,
          color: isSynced ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 3),
        Text(
          isSynced ? 'Synced' : 'Pending',
          style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w600,
            color:      isSynced ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }
}
