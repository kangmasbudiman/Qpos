import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';

class SaleItemDetail {
  final int id;
  final String productName;
  final double price;
  final int quantity;
  final double discount;
  final double subtotal;

  SaleItemDetail({
    required this.id,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.discount,
    required this.subtotal,
  });

  factory SaleItemDetail.fromDatabase(Map<String, dynamic> map) {
    return SaleItemDetail(
      id:          map['id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '-',
      price:       (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity:    map['quantity'] as int? ?? 0,
      discount:    (map['discount'] as num?)?.toDouble() ?? 0.0,
      subtotal:    (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SalesReportItem {
  final int id;
  final String invoiceNumber;
  final String date;
  final String customerName;
  final String paymentMethod;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String status;
  final int itemCount;

  SalesReportItem({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    required this.paymentMethod,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.status,
    required this.itemCount,
  });

  factory SalesReportItem.fromDatabase(Map<String, dynamic> map) {
    return SalesReportItem(
      id:            map['id'] as int? ?? 0,
      invoiceNumber: map['invoice_number'] as String? ?? 'LOCAL',
      date:          map['created_at'] as String? ?? '',
      customerName:  map['customer_name'] as String? ?? 'Umum',
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      subtotal:      (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount:      (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax:           (map['tax'] as num?)?.toDouble() ?? 0.0,
      total:         (map['total'] as num?)?.toDouble() ?? 0.0,
      status:        map['status'] as String? ?? 'completed',
      itemCount:     map['item_count'] as int? ?? 0,
    );
  }
}

class SalesReportSummary {
  final double grossSales;
  final double totalDiscount;
  final double totalTax;
  final double netSales;
  final int totalTransactions;
  final double averageTransaction;
  final Map<String, double> salesByPaymentMethod;
  final Map<String, double> salesByDay;

  SalesReportSummary({
    required this.grossSales,
    required this.totalDiscount,
    required this.totalTax,
    required this.netSales,
    required this.totalTransactions,
    required this.averageTransaction,
    required this.salesByPaymentMethod,
    required this.salesByDay,
  });
}

class SalesReportService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = Get.find<AuthService>();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final RxList<SalesReportItem> _reportItems = <SalesReportItem>[].obs;
  final Rxn<SalesReportSummary> _summary = Rxn<SalesReportSummary>();
  final RxBool _isLoading = false.obs;
  final RxBool _isExporting = false.obs;

  // Filters
  final Rx<DateTime> _dateFrom = DateTime.now().obs;
  final Rx<DateTime> _dateTo = DateTime.now().obs;
  final RxnInt _branchId = RxnInt();
  final RxString _paymentMethod = ''.obs; // '' = all
  final RxString _searchQuery = ''.obs;

  // Getters
  List<SalesReportItem> get reportItems => _reportItems;
  SalesReportSummary? get summary => _summary.value;
  bool get isLoading => _isLoading.value;
  bool get isExporting => _isExporting.value;
  DateTime get dateFrom => _dateFrom.value;
  DateTime get dateTo => _dateTo.value;
  int? get branchId => _branchId.value;
  String get paymentMethod => _paymentMethod.value;
  String get searchQuery => _searchQuery.value;

  @override
  void onInit() {
    super.onInit();
    // Set default date range to this month
    final now = DateTime.now();
    _dateFrom.value = DateTime(now.year, now.month, 1);
    _dateTo.value = now;
  }

  /// Set date filter
  void setDateRange(DateTime from, DateTime to) {
    _dateFrom.value = from;
    _dateTo.value = to;
    loadReport();
  }

  /// Set payment method filter
  void setPaymentMethod(String method) {
    _paymentMethod.value = method;
    loadReport();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery.value = query;
    loadReport();
  }

  /// Load report data
  Future<void> loadReport() async {
    _isLoading.value = true;
    try {
      await _loadFromLocal();
      
      final hasInternet = await _checkInternet();
      if (hasInternet) {
        await _loadFromBackend();
      }
    } catch (e) {
      print('❌ Error loading sales report: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Load from local database
  Future<void> _loadFromLocal() async {
    try {
      // viewBranchId: null = semua cabang (owner), non-null = cabang tertentu
      final branchId = _branchId.value ?? _authService.viewBranchId.value;

      // Build where clause
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (branchId != null) {
        whereClause += ' AND s.branch_id = ?';
        whereArgs.add(branchId);
      }

      // Date range filter — pakai substr(created_at,1,10) agar handle
      // format ISO 8601 (2026-02-23T14:30:00) maupun spasi (2026-02-23 14:30:00)
      final fromDate = DateFormat('yyyy-MM-dd').format(_dateFrom.value);
      final toDate   = DateFormat('yyyy-MM-dd').format(_dateTo.value);
      whereClause += ' AND substr(s.created_at, 1, 10) >= ?';
      whereArgs.add(fromDate);
      whereClause += ' AND substr(s.created_at, 1, 10) <= ?';
      whereArgs.add(toDate);

      // Payment method filter
      if (_paymentMethod.value.isNotEmpty) {
        whereClause += ' AND s.payment_method = ?';
        whereArgs.add(_paymentMethod.value);
      }

      // Search filter
      if (_searchQuery.value.isNotEmpty) {
        whereClause += ' AND (s.invoice_number LIKE ? OR c.name LIKE ?)';
        whereArgs.add('%${_searchQuery.value}%');
        whereArgs.add('%${_searchQuery.value}%');
      }
      
      print('📊 Loading sales report with filter: $whereClause');
      print('📊 Args: $whereArgs');
      
      // Get sales data with item count
      final results = await _db.rawQuery('''
        SELECT 
          s.id,
          s.invoice_number,
          s.branch_id,
          s.customer_id,
          s.subtotal,
          s.discount,
          s.tax,
          s.total,
          s.cash,
          s.change_amount,
          s.payment_method,
          s.status,
          s.notes,
          s.is_synced,
          s.synced_at,
          s.created_at,
          s.updated_at,
          c.name as customer_name,
          (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) as item_count
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE $whereClause
        ORDER BY s.created_at DESC
      ''', whereArgs);
      
      print('📊 Found ${results.length} sales records');
      
      _reportItems.value = results.map((row) =>
          SalesReportItem.fromDatabase(row)).toList();
      
      // Calculate summary
      calculateSummary();
      
      print('📊 Report items: ${_reportItems.length}');
      print('📊 Summary: ${_summary.value?.totalTransactions ?? 0} transactions');
      
    } catch (e) {
      print('❌ Error loading local report: $e');
      _reportItems.clear();
    }
  }

  /// Load from backend API
  Future<void> _loadFromBackend() async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;

      final branchId = _branchId.value ?? _authService.viewBranchId.value;
      final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom.value);
      final toStr   = DateFormat('yyyy-MM-dd').format(_dateTo.value);
      final branchParam = branchId != null ? '&branch_id=$branchId' : '';

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reports/sales?from=$fromStr&to=$toStr$branchParam&payment_method=${_paymentMethod.value}&search=${_searchQuery.value}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reportData = data['data'] as Map<String, dynamic>?;
        
        if (reportData != null) {
          // Update summary from backend if available
          final backendSummary = reportData['summary'] as Map<String, dynamic>?;
          if (backendSummary != null) {
            _summary.value = SalesReportSummary(
              grossSales: (backendSummary['gross_sales'] as num?)?.toDouble() ?? _summary.value?.grossSales ?? 0,
              totalDiscount: (backendSummary['total_discount'] as num?)?.toDouble() ?? _summary.value?.totalDiscount ?? 0,
              totalTax: (backendSummary['total_tax'] as num?)?.toDouble() ?? _summary.value?.totalTax ?? 0,
              netSales: (backendSummary['net_sales'] as num?)?.toDouble() ?? _summary.value?.netSales ?? 0,
              totalTransactions: backendSummary['total_transactions'] as int? ?? _summary.value?.totalTransactions ?? 0,
              averageTransaction: (backendSummary['average_transaction'] as num?)?.toDouble() ?? _summary.value?.averageTransaction ?? 0,
              salesByPaymentMethod: Map<String, double>.from(backendSummary['sales_by_payment_method'] ?? {}),
              salesByDay: Map<String, double>.from(backendSummary['sales_by_day'] ?? {}),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error loading backend report: $e');
    }
  }

  /// Calculate summary from local data
  void calculateSummary() {
    if (_reportItems.isEmpty) {
      _summary.value = null;
      return;
    }
    
    double grossSales = 0;
    double totalDiscount = 0;
    double totalTax = 0;
    Map<String, double> salesByPaymentMethod = {};
    Map<String, double> salesByDay = {};
    
    for (var item in _reportItems) {
      grossSales += item.subtotal;
      totalDiscount += item.discount;
      totalTax += item.tax;
      
      // Group by payment method
      salesByPaymentMethod[item.paymentMethod] = 
          (salesByPaymentMethod[item.paymentMethod] ?? 0) + item.total;
      
      // Group by day
      try {
        final date = DateTime.parse(item.date);
        final dayKey = DateFormat('EEE', 'id_ID').format(date);
        salesByDay[dayKey] = (salesByDay[dayKey] ?? 0) + item.total;
      } catch (e) {
        // Skip if date parsing fails
      }
    }
    
    double netSales = grossSales - totalDiscount + totalTax;
    int totalTransactions = _reportItems.length;
    double averageTransaction = totalTransactions > 0 ? netSales / totalTransactions : 0;
    
    _summary.value = SalesReportSummary(
      grossSales: grossSales,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      netSales: netSales,
      totalTransactions: totalTransactions,
      averageTransaction: averageTransaction,
      salesByPaymentMethod: salesByPaymentMethod,
      salesByDay: salesByDay,
    );
  }

  /// Export to PDF
  Future<void> exportToPDF() async {
    _isExporting.value = true;
    try {
      // PDF export logic will be implemented in the screen
      print('📄 Export to PDF...');
    } finally {
      _isExporting.value = false;
    }
  }

  /// Export to Excel
  Future<void> exportToExcel() async {
    _isExporting.value = true;
    try {
      // Excel export logic will be implemented in the screen
      print('📊 Export to Excel...');
    } finally {
      _isExporting.value = false;
    }
  }

  /// Get detail items for a specific sale
  Future<List<SaleItemDetail>> getItemsForSale(int saleId) async {
    final rows = await _db.rawQuery('''
      SELECT id, product_name, price, quantity, discount, subtotal
      FROM sale_items
      WHERE sale_id = ?
      ORDER BY id ASC
    ''', [saleId]);
    return rows.map((r) => SaleItemDetail.fromDatabase(r)).toList();
  }

  /// Reset filters
  void resetFilters() {
    final now = DateTime.now();
    _dateFrom.value = DateTime(now.year, now.month, 1);
    _dateTo.value = now;
    _branchId.value = null;
    _paymentMethod.value = '';
    _searchQuery.value = '';
    loadReport();
  }

  /// Check internet connection
  Future<bool> _checkInternet() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
