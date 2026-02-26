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

import '../../services/report/inventory_report_service.dart';
import '../../services/database/database_helper.dart';

// Import PdfColors separately
import 'package:pdf/pdf.dart' show PdfColors;

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({Key? key}) : super(key: key);

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  late InventoryReportService _service;
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _searchCtrl = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _service = Get.put(InventoryReportService());
    _service.loadReport();
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
                          child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFFF6B35), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Obx(() => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Laporan Stok',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              '${_service.reportItems.length} produk',
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];

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

              // Category, Status, Low Stock Toggle
              Row(
                children: [
                  Expanded(child: _categoryDropdown(categories)),
                  const SizedBox(width: 6),
                  Expanded(child: _stockStatusDropdown()),
                  const SizedBox(width: 6),
                  _lowStockToggleCompact(),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _lowStockToggleCompact() {
    return Obx(() => SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: _service.showLowStockOnly
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _service.toggleLowStockOnly(),
          child: Tooltip(
            message: 'Filter Stok Rendah',
            child: Icon(
              Icons.warning_rounded,
              size: 18,
              color: _service.showLowStockOnly
                  ? const Color(0xFFFF9800)
                  : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    ));
  }

  Future<List<Map<String, dynamic>>> _getCategories() async {
    final db = DatabaseHelper();
    return await db.query('categories', orderBy: 'name ASC');
  }

  Widget _categoryDropdown(List<Map<String, dynamic>> categories) {
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
          child: DropdownButton<int>(
            value: _service.categoryId,
            isExpanded: true,
            isDense: true,
            icon: Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey.shade500),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D26)),
            hint: Text('Kategori', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            items: [
              DropdownMenuItem(value: null, child: Text('Semua Kategori', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
              ...categories.map((cat) => DropdownMenuItem(
                value: cat['id'] as int,
                child: Text(cat['name'] as String, style: const TextStyle(fontSize: 12)),
              )),
            ],
            onChanged: (value) => _service.setCategory(value),
          ),
        ),
      ),
    );
  }

  Widget _stockStatusDropdown() {
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
            value: _service.stockStatus.isEmpty ? null : _service.stockStatus,
            isExpanded: true,
            isDense: true,
            icon: Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey.shade500),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D26)),
            hint: Text('Status Stok', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            items: [
              DropdownMenuItem(value: null, child: Text('Semua Status', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
              const DropdownMenuItem(value: 'in_stock', child: Text('Aman', style: TextStyle(fontSize: 12))),
              const DropdownMenuItem(value: 'low_stock', child: Text('Rendah', style: TextStyle(fontSize: 12))),
              const DropdownMenuItem(value: 'out_of_stock', child: Text('Habis', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (value) => _service.setStockStatus(value ?? ''),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari produk / SKU...',
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
      if (summary == null) return const SizedBox.shrink();

      return Row(
        children: [
          Expanded(child: _summaryChip(
            label: 'Total',
            value: '${summary.totalProducts}',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF2196F3),
          )),
          const SizedBox(width: 6),
          Expanded(child: _summaryChip(
            label: 'Aman',
            value: '${summary.inStockProducts}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF4CAF50),
          )),
          const SizedBox(width: 6),
          Expanded(child: _summaryChip(
            label: 'Rendah',
            value: '${summary.lowStockProducts}',
            icon: Icons.warning_rounded,
            color: const Color(0xFFFF9800),
          )),
          const SizedBox(width: 6),
          Expanded(child: _summaryChip(
            label: 'Habis',
            value: '${summary.outOfStockProducts}',
            icon: Icons.error_rounded,
            color: Colors.red,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
                  'Belum ada data produk',
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
                    'Daftar Produk',
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
                      '${items.length} Produk',
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
                  Expanded(flex: 3, child: _th('Produk')),
                  Expanded(flex: 2, child: _th('SKU')),
                  Expanded(flex: 2, child: _th('Kategori')),
                  Expanded(flex: 2, child: _th('Stok', align: TextAlign.end)),
                  Expanded(flex: 2, child: _th('Harga', align: TextAlign.end)),
                  Expanded(flex: 2, child: _th('Nilai', align: TextAlign.end)),
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

  Widget _buildTableRow(InventoryReportItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: material.Border(
          bottom: material.BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unit: ${item.unit}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.sku,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.categoryName ?? '-',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  '${item.localStock}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item.localStock <= 0 
                        ? Colors.red 
                        : item.localStock <= item.minStock 
                            ? const Color(0xFFFF9800) 
                            : const Color(0xFF4CAF50),
                  ),
                ),
                if (item.localStock <= item.minStock && item.localStock > 0)
                  Text(
                    'Min: ${item.minStock}',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency.format(item.price),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency.format(item.stockValue),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _stockStatusBadge(item.stockStatus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;
    
    switch (status) {
      case 'in_stock':
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle_rounded;
        label = '✓';
        break;
      case 'low_stock':
        color = const Color(0xFFFF9800);
        icon = Icons.warning_rounded;
        label = '⚠';
        break;
      case 'out_of_stock':
        color = Colors.red;
        icon = Icons.error_rounded;
        label = '✕';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_rounded;
        label = '?';
    }
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }

  // ── Export Functions ──────────────────────────────────────────────────────

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    final summary = _service.summary;
    final items = _service.reportItems;
    
    if (summary == null || items.isEmpty) {
      Get.snackbar('Info', 'Tidak ada data untuk diekspor',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange);
      return;
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text('LAPORAN STOK PRODUK',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              
              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _pdfSummaryCell('Total Produk', '${summary.totalProducts}'),
                    _pdfSummaryCell('Stok Aman', '${summary.inStockProducts}'),
                    _pdfSummaryCell('Stok Rendah', '${summary.lowStockProducts}'),
                    _pdfSummaryCell('Stok Habis', '${summary.outOfStockProducts}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Table Header
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('Produk', bold: true),
                      _pdfCell('SKU', bold: true),
                      _pdfCell('Stok', bold: true),
                      _pdfCell('Harga', bold: true, align: pw.TextAlign.right),
                      _pdfCell('Nilai', bold: true, align: pw.TextAlign.right),
                      _pdfCell('Status', bold: true),
                    ],
                  ),
                  ...items.map((item) => pw.TableRow(
                    children: [
                      _pdfCell(item.productName),
                      _pdfCell(item.sku),
                      _pdfCell('${item.localStock}'),
                      _pdfCell(_currency.format(item.price), align: pw.TextAlign.right),
                      _pdfCell(_currency.format(item.stockValue), align: pw.TextAlign.right),
                      _pdfCell(_getStockStatusLabel(item.stockStatus)),
                    ],
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );
    
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Laporan_Stok_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  String _getStockStatusLabel(String status) {
    switch (status) {
      case 'in_stock': return 'Aman';
      case 'low_stock': return 'Rendah';
      case 'out_of_stock': return 'Habis';
      default: return '-';
    }
  }

  pw.Widget _pdfSummaryCell(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          )),
    );
  }

  Future<void> _exportToExcel() async {
    final summary = _service.summary;
    final items = _service.reportItems;
    
    if (summary == null || items.isEmpty) {
      Get.snackbar('Info', 'Tidak ada data untuk diekspor',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange);
      return;
    }
    
    var excel = excel_lib.Excel.createExcel();
    var sheet = excel['Laporan Stok'];
    
    // Header
    sheet.appendRow([
      excel_lib.TextCellValue('LAPORAN STOK PRODUK'),
    ]);
    sheet.appendRow([]);
    
    // Summary
    sheet.appendRow([
      excel_lib.TextCellValue('Total Produk'),
      excel_lib.IntCellValue(summary.totalProducts),
    ]);
    sheet.appendRow([
      excel_lib.TextCellValue('Stok Aman'),
      excel_lib.IntCellValue(summary.inStockProducts),
    ]);
    sheet.appendRow([
      excel_lib.TextCellValue('Stok Rendah'),
      excel_lib.IntCellValue(summary.lowStockProducts),
    ]);
    sheet.appendRow([
      excel_lib.TextCellValue('Stok Habis'),
      excel_lib.IntCellValue(summary.outOfStockProducts),
    ]);
    sheet.appendRow([]);
    
    // Table Header
    sheet.appendRow([
      excel_lib.TextCellValue('Produk'),
      excel_lib.TextCellValue('SKU'),
      excel_lib.TextCellValue('Kategori'),
      excel_lib.TextCellValue('Stok'),
      excel_lib.TextCellValue('Min Stock'),
      excel_lib.TextCellValue('Harga'),
      excel_lib.TextCellValue('Nilai Stok'),
      excel_lib.TextCellValue('Status'),
    ]);
    
    // Data Rows
    for (var item in items) {
      sheet.appendRow([
        excel_lib.TextCellValue(item.productName),
        excel_lib.TextCellValue(item.sku),
        excel_lib.TextCellValue(item.categoryName ?? '-'),
        excel_lib.IntCellValue(item.localStock),
        excel_lib.IntCellValue(item.minStock),
        excel_lib.DoubleCellValue(item.price),
        excel_lib.DoubleCellValue(item.stockValue),
        excel_lib.TextCellValue(_getStockStatusLabel(item.stockStatus)),
      ]);
    }
    
    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/Laporan_Stok_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
    
    Get.snackbar('Berhasil', 'File Excel tersimpan di $filePath',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        duration: const Duration(seconds: 4));
  }
}

