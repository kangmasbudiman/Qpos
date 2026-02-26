import 'dart:io';
import 'package:flutter/material.dart' hide Border;
import 'package:flutter/material.dart' as material;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';

import '../../services/report/sales_report_service.dart';
import '../../services/auth/auth_service.dart';
import '../widgets/branch_filter_bar.dart';

// Import PdfColors separately
import 'package:pdf/pdf.dart' show PdfColors;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({Key? key}) : super(key: key);

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late SalesReportService _service;
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _searchCtrl = TextEditingController();

  // Expand state: saleId → list items (null = belum load, [] = loading, [...] = loaded)
  final Map<int, List<SaleItemDetail>?> _expandedItems = {};
  int? _expandedSaleId;
  
  @override
  void initState() {
    super.initState();
    _service = Get.isRegistered<SalesReportService>()
        ? Get.find<SalesReportService>()
        : Get.put(SalesReportService());
    // Reset filter ke bulan ini setiap kali halaman dibuka
    final now = DateTime.now();
    _service.setDateRange(DateTime(now.year, now.month, 1), now);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: const Color(0xFF1E2235),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: material.Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFF6B35), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Obx(() => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Laporan Penjualan',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              '${_service.reportItems.length} transaksi',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: () => _service.loadReport(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Export',
                onSelected: (value) {
                  if (value == 'pdf') _exportToPDF();
                  if (value == 'excel') _exportToExcel();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('Export PDF'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'excel',
                    child: Row(children: [
                      Icon(Icons.table_chart_rounded, color: Colors.green, size: 18),
                      SizedBox(width: 10),
                      Text('Export Excel'),
                    ]),
                  ),
                ],
              ),
            ],
          ),

          // ── Branch filter (owner only) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: BranchFilterBar(onChanged: () => _service.loadReport()),
            ),
          ),

          // ── Filter ──
          SliverToBoxAdapter(child: _buildFilterSection()),

          // ── Content ──
          SliverToBoxAdapter(
            child: Obx(() {
              if (_service.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                child: Column(
                  children: [
                    _buildSummarySection(),
                    const SizedBox(height: 12),
                    _buildDataTable(),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Filter Section ────────────────────────────────────────────────────────

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search + Reset
          Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 6),
              _resetButton(),
            ],
          ),
          const SizedBox(height: 8),

          // Date From, Date To, Payment Method
          Row(
            children: [
              Expanded(child: _datePickerField(
                label: 'Dari',
                value: _service.dateFrom,
                onTap: () => _selectDateRange(true),
              )),
              const SizedBox(width: 6),
              Expanded(child: _datePickerField(
                label: 'Sampai',
                value: _service.dateTo,
                onTap: () => _selectDateRange(false),
              )),
              const SizedBox(width: 6),
              Expanded(child: _paymentMethodDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resetButton() {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _searchCtrl.clear();
            _service.resetFilters();
          },
          child: const Icon(Icons.refresh_rounded, color: Color(0xFFFF6B35), size: 18),
        ),
      ),
    );
  }

  Widget _datePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 36,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: material.Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    Text(
                      _dateFormat.format(value),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentMethodDropdown() {
    return Obx(() {
      final currentValue = _service.paymentMethod.isEmpty ? null : _service.paymentMethod;
      return SizedBox(
        height: 36,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: material.Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              hint: Text('Metode', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey.shade500),
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D26)),
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem<String>(value: null, child: Text('Semua', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                const DropdownMenuItem<String>(value: 'cash', child: Text('Tunai', style: TextStyle(fontSize: 12))),
                const DropdownMenuItem<String>(value: 'transfer', child: Text('Transfer', style: TextStyle(fontSize: 12))),
                const DropdownMenuItem<String>(value: 'debit', child: Text('Debit', style: TextStyle(fontSize: 12))),
                const DropdownMenuItem<String>(value: 'credit', child: Text('Kredit', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (String? value) => _service.setPaymentMethod(value ?? ''),
            ),
          ),
        ),
      );
    });
  }

  Widget _searchField() {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari invoice / customer...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF6B35), size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _service.setSearchQuery('');
                  },
                  child: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                )
              : null,
        ),
        onChanged: (value) => _service.setSearchQuery(value),
      ),
    );
  }

  // ── Summary Section ───────────────────────────────────────────────────────

  Widget _buildSummarySection() {
    return Obx(() {
      final summary = _service.summary;

      if (summary == null && _service.reportItems.isNotEmpty) {
        _service.calculateSummary();
      }
      final currentSummary = _service.summary;
      if (currentSummary == null) return const SizedBox.shrink();

      return Row(
        children: [
          Expanded(child: _summaryChip(
            label: 'Penjualan',
            value: _currency.format(currentSummary.netSales),
            icon: Icons.attach_money_rounded,
            color: const Color(0xFF4CAF50),
          )),
          const SizedBox(width: 6),
          Expanded(child: _summaryChip(
            label: 'Transaksi',
            value: '${currentSummary.totalTransactions}',
            icon: Icons.receipt_rounded,
            color: const Color(0xFF2196F3),
          )),
          const SizedBox(width: 6),
          Expanded(child: _summaryChip(
            label: 'Rata-rata',
            value: _currency.format(currentSummary.averageTransaction),
            icon: Icons.trending_up_rounded,
            color: const Color(0xFFFF9800),
          )),
          const SizedBox(width: 6),
          Expanded(child: _summaryChip(
            label: 'Diskon',
            value: _currency.format(currentSummary.totalDiscount),
            icon: Icons.discount_rounded,
            color: const Color(0xFF9C27B0),
          )),
        ],
      );
    });
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: material.Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Data Table ────────────────────────────────────────────────────────────

  Widget _buildDataTable() {
    return Obx(() {
      final items = _service.reportItems;
      
      if (items.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Belum ada data penjualan',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
      
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFEA580C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length} Transaksi',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            // Table Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _th('Invoice')),
                  Expanded(flex: 2, child: _th('Tanggal')),
                  Expanded(flex: 2, child: _th('Customer')),
                  Expanded(flex: 2, child: _th('Metode')),
                  Expanded(flex: 2, child: _th('Item', align: TextAlign.end)),
                  Expanded(flex: 2, child: _th('Total', align: TextAlign.end)),
                  Expanded(flex: 1, child: _th('Status', align: TextAlign.center)),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Data Rows
            ...items.map((item) => _buildTableRow(item)),
          ],
        ),
      );
    });
  }

  Widget _th(String label, {TextAlign align = TextAlign.start}) {
    return Text(
      label,
      textAlign: align,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildTableRow(SalesReportItem item) {
    final isExpanded = _expandedSaleId == item.id;
    final loadedItems = _expandedItems[item.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Baris utama ──────────────────────────────────────────────
        InkWell(
          onTap: () async {
            if (isExpanded) {
              setState(() => _expandedSaleId = null);
              return;
            }
            setState(() {
              _expandedSaleId = item.id;
              // Set null = sedang loading jika belum pernah di-load
              if (!_expandedItems.containsKey(item.id)) {
                _expandedItems[item.id] = null;
              }
            });
            if (!_expandedItems.containsKey(item.id) ||
                _expandedItems[item.id] == null) {
              final items = await _service.getItemsForSale(item.id);
              if (mounted) setState(() => _expandedItems[item.id] = items);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isExpanded
                  ? const Color(0xFFFFF8F5)
                  : Colors.transparent,
              border: material.Border(
                bottom: material.BorderSide(
                  color: isExpanded
                      ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
                      : Colors.grey.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Invoice + item count
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: const Color(0xFFFF6B35),
                          ),
                          Text(
                            '${item.itemCount} item',
                            style: TextStyle(
                              fontSize: 10,
                              color: isExpanded
                                  ? const Color(0xFFFF6B35)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatDate(item.date),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.customerName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _paymentMethodBadge(item.paymentMethod),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.itemCount}',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _currency.format(item.total),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(child: _statusBadge(item.status)),
                ),
              ],
            ),
          ),
        ),

        // ── Detail item (expand) ──────────────────────────────────────
        if (isExpanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: const Color(0xFFFFFAF8),
            child: loadedItems == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B35)),
                        ),
                      ),
                    ),
                  )
                : loadedItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Tidak ada detail item',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header item table
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                            color: const Color(0xFFFFF0EB),
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 4,
                                  child: Text('Produk',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B35))),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text('Harga',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B35))),
                                ),
                                const Expanded(
                                  flex: 1,
                                  child: Text('Qty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B35))),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text('Diskon',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B35))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Subtotal',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700)),
                                ),
                              ],
                            ),
                          ),
                          // Item rows
                          ...loadedItems.map((si) => Container(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 8, 12, 8),
                                decoration: BoxDecoration(
                                  border: material.Border(
                                    bottom: material.BorderSide(
                                        color: Colors.orange.shade50, width: 1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        si.productName,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF1A1D26)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency.format(si.price),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'x${si.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1D26),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        si.discount > 0
                                            ? '-${_currency.format(si.discount)}'
                                            : '-',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: si.discount > 0
                                                ? Colors.red.shade400
                                                : Colors.grey.shade400),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency.format(si.subtotal),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          // Footer total
                          Container(
                            padding:
                                const EdgeInsets.fromLTRB(24, 8, 12, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                                Text(
                                  _currency.format(item.total),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
      ],
    );
  }

  Widget _paymentMethodBadge(String method) {
    Color color;
    String label;
    
    switch (method) {
      case 'cash':
        color = const Color(0xFF4CAF50);
        label = 'Tunai';
        break;
      case 'transfer':
        color = const Color(0xFF2196F3);
        label = 'Transfer';
        break;
      case 'debit':
        color = const Color(0xFFFF9800);
        label = 'Debit';
        break;
      case 'credit':
        color = const Color(0xFF9C27B0);
        label = 'Kredit';
        break;
      default:
        color = Colors.grey;
        label = method;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: material.Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'completed':
        color = const Color(0xFF4CAF50);
        label = '✓';
        break;
      case 'pending':
        color = const Color(0xFFFF9800);
        label = '⏳';
        break;
      case 'cancelled':
        color = Colors.red;
        label = '✕';
        break;
      default:
        color = Colors.grey;
        label = '?';
    }
    
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (e) {
      return '-';
    }
  }

  Future<void> _selectDateRange(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _service.dateFrom : _service.dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF6B35),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          // If picking "from" date
          if (picked.isAfter(_service.dateTo)) {
            // If from date is after to date, set to date same as from
            _service.setDateRange(picked, picked);
          } else {
            // Otherwise just update from date
            _service.setDateRange(picked, _service.dateTo);
          }
        } else {
          // If picking "to" date
          if (picked.isBefore(_service.dateFrom)) {
            // If to date is before from date, set from date same as to
            _service.setDateRange(picked, picked);
          } else {
            // Otherwise just update to date
            _service.setDateRange(_service.dateFrom, picked);
          }
        }
      });
    }
  }

  // ── Export Functions ──────────────────────────────────────────────────────

  static const _orange  = PdfColor.fromInt(0xFFFF6B35);
  static const _dark    = PdfColor.fromInt(0xFF1E2235);
  static const _green   = PdfColor.fromInt(0xFF4CAF50);
  static const _red     = PdfColor.fromInt(0xFFE53935);

  String _paymentLabel(String m) {
    const map = {
      'cash': 'Tunai', 'debit': 'Debit', 'credit': 'Kredit',
      'qris': 'QRIS', 'transfer': 'Transfer', 'mixed': 'Campuran',
    };
    return map[m] ?? m;
  }

  Future<void> _exportToPDF() async {
    final summary = _service.summary;
    final items   = _service.reportItems;

    if (summary == null || items.isEmpty) {
      Get.snackbar('Info', 'Tidak ada data untuk diekspor',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange);
      return;
    }

    // Loading dialog
    Get.dialog(
      const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B35))),
          SizedBox(width: 16),
          Text('Membuat PDF...'),
        ]),
      ),
      barrierDismissible: false,
    );

    try {
      // Load semua detail item untuk setiap transaksi
      final Map<int, List<SaleItemDetail>> allItems = {};
      for (final item in items) {
        allItems[item.id] = await _service.getItemsForSale(item.id);
      }

      final pdf        = pw.Document();
      final now        = DateTime.now();
      final dateStr    = '${_dateFormat.format(_service.dateFrom)} - ${_dateFormat.format(_service.dateTo)}';
      final generated  = DateFormat('dd/MM/yyyy HH:mm').format(now);

      // ── Halaman ringkasan + tabel transaksi ─────────────────────────
      pdf.addPage(
        pw.MultiPage(
          pageFormat:   PdfPageFormat.a4,
          margin:       const pw.EdgeInsets.all(32),
          header:       (ctx) => _pdfPageHeader(dateStr, generated),
          footer:       (ctx) => _pdfPageFooter(ctx),
          build:        (ctx) => [
            // Summary cards
            _pdfSummarySection(summary),
            pw.SizedBox(height: 20),

            // Tabel ringkasan transaksi
            pw.Text('Daftar Transaksi',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _dark)),
            pw.SizedBox(height: 8),
            pw.Table(
              border:       pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(2),
                6: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _dark),
                  children: [
                    _pdfTh('Invoice'),
                    _pdfTh('Tanggal'),
                    _pdfTh('Customer'),
                    _pdfTh('Metode'),
                    _pdfTh('Item', align: pw.TextAlign.center),
                    _pdfTh('Total', align: pw.TextAlign.right),
                    _pdfTh('Status', align: pw.TextAlign.center),
                  ],
                ),
                // Data rows
                ...items.asMap().entries.map((e) {
                  final idx  = e.key;
                  final item = e.value;
                  final bg   = idx.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF9F9F9);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _pdfTd(item.invoiceNumber, bold: true),
                      _pdfTd(_formatDate(item.date)),
                      _pdfTd(item.customerName),
                      _pdfTd(_paymentLabel(item.paymentMethod)),
                      _pdfTd('${item.itemCount}', align: pw.TextAlign.center),
                      _pdfTd(_currency.format(item.total),
                          align: pw.TextAlign.right,
                          color: _green, bold: true),
                      _pdfTd(
                        item.status == 'completed' ? '✓' :
                        item.status == 'cancelled' ? '✕' : '⏳',
                        align: pw.TextAlign.center,
                        color: item.status == 'completed' ? _green :
                               item.status == 'cancelled' ? _red : _orange,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Detail item per transaksi
            pw.Text('Detail Item per Transaksi',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _dark)),
            pw.SizedBox(height: 8),
            ...items.map((item) {
              final saleItems = allItems[item.id] ?? [];
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Sub-header transaksi
                  pw.Container(
                    padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
                    decoration: const pw.BoxDecoration(color: _orange),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(item.invoiceNumber,
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.Text(
                          '${_formatDate(item.date)}  |  ${item.customerName}  |  ${_paymentLabel(item.paymentMethod)}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                      ],
                    ),
                  ),
                  // Item table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(2),
                      4: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFF0EB)),
                        children: [
                          _pdfTh('Produk', color: _orange),
                          _pdfTh('Harga', align: pw.TextAlign.right, color: _orange),
                          _pdfTh('Qty', align: pw.TextAlign.center, color: _orange),
                          _pdfTh('Diskon', align: pw.TextAlign.right, color: _orange),
                          _pdfTh('Subtotal', align: pw.TextAlign.right, color: _orange),
                        ],
                      ),
                      ...saleItems.map((si) => pw.TableRow(
                        children: [
                          _pdfTd(si.productName),
                          _pdfTd(_currency.format(si.price), align: pw.TextAlign.right),
                          _pdfTd('x${si.quantity}', align: pw.TextAlign.center, bold: true),
                          _pdfTd(
                            si.discount > 0 ? '-${_currency.format(si.discount)}' : '-',
                            align: pw.TextAlign.right,
                            color: si.discount > 0 ? _red : PdfColors.grey,
                          ),
                          _pdfTd(_currency.format(si.subtotal),
                              align: pw.TextAlign.right, color: _green, bold: true),
                        ],
                      )),
                      // Footer row total
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F6FA)),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('',),
                          ),
                          pw.SizedBox(),
                          pw.SizedBox(),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('Total',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ),
                          _pdfTd(_currency.format(item.total),
                              align: pw.TextAlign.right, color: _orange, bold: true),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                ],
              );
            }),
          ],
        ),
      );

      Get.back(); // tutup loading dialog
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name: 'Laporan_Penjualan_${DateFormat('yyyyMMdd').format(now)}.pdf',
      );
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'Gagal membuat PDF: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // PDF page header
  pw.Widget _pdfPageHeader(String period, String generated) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _orange, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('LAPORAN PENJUALAN',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _dark)),
            pw.SizedBox(height: 2),
            pw.Text('Periode: $period',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Q-POS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _orange)),
            pw.Text('Dicetak: $generated',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
        ],
      ),
    );
  }

  // PDF page footer
  pw.Widget _pdfPageFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Q-POS — Laporan Penjualan',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // PDF summary section
  pw.Widget _pdfSummarySection(SalesReportSummary summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F6FA),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _pdfSummaryCard('Total Penjualan', _currency.format(summary.netSales), _orange),
          _pdfSummaryCard('Transaksi', '${summary.totalTransactions}x', _dark),
          _pdfSummaryCard('Rata-rata', _currency.format(summary.averageTransaction), _green),
          _pdfSummaryCard('Total Diskon', _currency.format(summary.totalDiscount), _red),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryCard(String label, String value, PdfColor accent) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
      ],
    );
  }

  // PDF table header cell
  pw.Widget _pdfTh(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor color = PdfColors.white}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  // PDF table data cell
  pw.Widget _pdfTd(String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          )),
    );
  }

  // ── Excel Export ──────────────────────────────────────────────────────────

  Future<void> _exportToExcel() async {
    final summary = _service.summary;
    final items   = _service.reportItems;

    if (summary == null || items.isEmpty) {
      Get.snackbar('Info', 'Tidak ada data untuk diekspor',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange);
      return;
    }

    // Loading dialog
    Get.dialog(
      const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B35))),
          SizedBox(width: 16),
          Text('Membuat Excel...'),
        ]),
      ),
      barrierDismissible: false,
    );

    try {
      // Load semua detail item
      final Map<int, List<SaleItemDetail>> allItems = {};
      for (final item in items) {
        allItems[item.id] = await _service.getItemsForSale(item.id);
      }

      final xcel       = excel_lib.Excel.createExcel();
      final period     = '${_dateFormat.format(_service.dateFrom)} - ${_dateFormat.format(_service.dateTo)}';
      final generated  = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // Style helpers
      excel_lib.CellStyle headerStyle() => excel_lib.CellStyle(
        bold: true,
        fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#1E2235'),
      );
      excel_lib.CellStyle subHeaderStyle() => excel_lib.CellStyle(
        bold: true,
        fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#FF6B35'),
      );
      excel_lib.CellStyle summaryLabelStyle() => excel_lib.CellStyle(
        bold: true,
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#F5F6FA'),
      );
      excel_lib.CellStyle totalStyle() => excel_lib.CellStyle(
        bold: true,
        fontColorHex: excel_lib.ExcelColor.fromHexString('#FF6B35'),
      );

      void setCell(excel_lib.Sheet sh, int row, int col, excel_lib.CellValue val,
          [excel_lib.CellStyle? style]) {
        final cell = sh.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = val;
        if (style != null) cell.cellStyle = style;
      }

      // ════════════════════════════════════════════════════════════════
      // Sheet 1: Ringkasan
      // ════════════════════════════════════════════════════════════════
      final sh1 = xcel['Ringkasan'];

      // Title
      setCell(sh1, 0, 0, excel_lib.TextCellValue('LAPORAN PENJUALAN'),
          excel_lib.CellStyle(bold: true, fontSize: 14));
      setCell(sh1, 1, 0, excel_lib.TextCellValue('Periode: $period'));
      setCell(sh1, 2, 0, excel_lib.TextCellValue('Digenerate: $generated'));

      // Summary
      int r = 4;
      setCell(sh1, r, 0, excel_lib.TextCellValue('RINGKASAN'), summaryLabelStyle());
      r++;
      final summaryData = [
        ['Total Penjualan (Neto)',   excel_lib.DoubleCellValue(summary.netSales)],
        ['Total Transaksi',          excel_lib.IntCellValue(summary.totalTransactions)],
        ['Rata-rata Transaksi',      excel_lib.DoubleCellValue(summary.averageTransaction)],
        ['Total Diskon',             excel_lib.DoubleCellValue(summary.totalDiscount)],
        ['Total Pajak',              excel_lib.DoubleCellValue(summary.totalTax)],
        ['Total Bruto',              excel_lib.DoubleCellValue(summary.grossSales)],
      ];
      for (final row in summaryData) {
        setCell(sh1, r, 0, excel_lib.TextCellValue(row[0] as String), summaryLabelStyle());
        setCell(sh1, r, 1, row[1] as excel_lib.CellValue);
        r++;
      }

      // Penjualan per metode bayar
      r++;
      setCell(sh1, r, 0, excel_lib.TextCellValue('Per Metode Bayar'), summaryLabelStyle());
      r++;
      for (final entry in summary.salesByPaymentMethod.entries) {
        setCell(sh1, r, 0, excel_lib.TextCellValue(_paymentLabel(entry.key)));
        setCell(sh1, r, 1, excel_lib.DoubleCellValue(entry.value));
        r++;
      }

      r++;
      // Tabel transaksi
      setCell(sh1, r, 0, excel_lib.TextCellValue('DAFTAR TRANSAKSI'), summaryLabelStyle());
      r++;
      final txHeaders = ['No', 'Invoice', 'Tanggal', 'Customer', 'Metode Bayar',
                         'Jml Item', 'Subtotal', 'Diskon', 'Pajak', 'Total', 'Status'];
      for (int c = 0; c < txHeaders.length; c++) {
        setCell(sh1, r, c, excel_lib.TextCellValue(txHeaders[c]), headerStyle());
      }
      r++;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        setCell(sh1, r, 0,  excel_lib.IntCellValue(i + 1));
        setCell(sh1, r, 1,  excel_lib.TextCellValue(item.invoiceNumber));
        setCell(sh1, r, 2,  excel_lib.TextCellValue(_formatDate(item.date)));
        setCell(sh1, r, 3,  excel_lib.TextCellValue(item.customerName));
        setCell(sh1, r, 4,  excel_lib.TextCellValue(_paymentLabel(item.paymentMethod)));
        setCell(sh1, r, 5,  excel_lib.IntCellValue(item.itemCount));
        setCell(sh1, r, 6,  excel_lib.DoubleCellValue(item.subtotal));
        setCell(sh1, r, 7,  excel_lib.DoubleCellValue(item.discount));
        setCell(sh1, r, 8,  excel_lib.DoubleCellValue(item.tax));
        setCell(sh1, r, 9,  excel_lib.DoubleCellValue(item.total));
        setCell(sh1, r, 10, excel_lib.TextCellValue(item.status));
        r++;
      }
      // Grand total row
      setCell(sh1, r, 8,  excel_lib.TextCellValue('GRAND TOTAL'), totalStyle());
      setCell(sh1, r, 9,  excel_lib.DoubleCellValue(summary.netSales), totalStyle());

      // ════════════════════════════════════════════════════════════════
      // Sheet 2: Detail Item
      // ════════════════════════════════════════════════════════════════
      final sh2 = xcel['Detail Item'];

      setCell(sh2, 0, 0, excel_lib.TextCellValue('DETAIL ITEM PER TRANSAKSI'),
          excel_lib.CellStyle(bold: true, fontSize: 13));
      setCell(sh2, 1, 0, excel_lib.TextCellValue('Periode: $period'));

      int dr = 3;
      for (final item in items) {
        // Sub-header transaksi
        final txLabel = '${item.invoiceNumber}  |  ${_formatDate(item.date)}  |  ${item.customerName}  |  ${_paymentLabel(item.paymentMethod)}';
        setCell(sh2, dr, 0, excel_lib.TextCellValue(txLabel), subHeaderStyle());
        // merge look — set same style across columns
        for (int c = 1; c <= 5; c++) {
          setCell(sh2, dr, c, excel_lib.TextCellValue(''), subHeaderStyle());
        }
        dr++;

        // Item table header
        final itemHeaders = ['Produk', 'Harga Satuan', 'Qty', 'Diskon', 'Subtotal'];
        for (int c = 0; c < itemHeaders.length; c++) {
          setCell(sh2, dr, c, excel_lib.TextCellValue(itemHeaders[c]), headerStyle());
        }
        dr++;

        final saleItems = allItems[item.id] ?? [];
        for (final si in saleItems) {
          setCell(sh2, dr, 0, excel_lib.TextCellValue(si.productName));
          setCell(sh2, dr, 1, excel_lib.DoubleCellValue(si.price));
          setCell(sh2, dr, 2, excel_lib.IntCellValue(si.quantity));
          setCell(sh2, dr, 3, excel_lib.DoubleCellValue(si.discount));
          setCell(sh2, dr, 4, excel_lib.DoubleCellValue(si.subtotal));
          dr++;
        }

        // Total row
        setCell(sh2, dr, 3, excel_lib.TextCellValue('Total'), totalStyle());
        setCell(sh2, dr, 4, excel_lib.DoubleCellValue(item.total), totalStyle());
        dr++;
        dr++; // spasi antar transaksi
      }

      // Hapus sheet default kosong
      xcel.delete('Sheet1');

      // Simpan & buka
      final directory = await getApplicationDocumentsDirectory();
      final fileName  = 'Laporan_Penjualan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath  = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(xcel.encode()!);

      Get.back(); // tutup loading dialog
      Get.snackbar(
        'Excel Tersimpan',
        filePath,
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText:       Colors.white,
        duration:        const Duration(seconds: 5),
        margin:          const EdgeInsets.all(12),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'Gagal membuat Excel: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

