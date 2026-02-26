import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class ProfitLossSummary {
  // Pendapatan
  final double grossSales;
  final double totalDiscount;
  final double totalTax;
  final double netSales;
  final int totalTransactions;
  // HPP
  final double hpp;
  // Laba
  final double grossProfit;
  final double grossMargin;
  final double netProfit;
  final double netMargin;
  // Pembelian
  final double totalPurchases;
  final int totalPurchaseCount;
  // Breakdown
  final List<PaymentBreakdownItem> paymentBreakdown;
  final List<TopProductItem> topProducts;
  final List<DailyRevenueItem> dailyRevenue;

  ProfitLossSummary({
    required this.grossSales,
    required this.totalDiscount,
    required this.totalTax,
    required this.netSales,
    required this.totalTransactions,
    required this.hpp,
    required this.grossProfit,
    required this.grossMargin,
    required this.netProfit,
    required this.netMargin,
    required this.totalPurchases,
    required this.totalPurchaseCount,
    required this.paymentBreakdown,
    required this.topProducts,
    required this.dailyRevenue,
  });
}

class PaymentBreakdownItem {
  final String method;
  final double total;
  final int count;
  PaymentBreakdownItem({required this.method, required this.total, required this.count});
}

class TopProductItem {
  final String productName;
  final int qty;
  final double revenue;
  TopProductItem({required this.productName, required this.qty, required this.revenue});
}

class DailyRevenueItem {
  final String date;
  final double revenue;
  final int transactions;
  DailyRevenueItem({required this.date, required this.revenue, required this.transactions});
}

// ── Service ──────────────────────────────────────────────────────────────────

class ProfitLossService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = Get.find<AuthService>();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final Rxn<ProfitLossSummary> _summary = Rxn<ProfitLossSummary>();
  final RxBool _isLoading = false.obs;
  final Rx<DateTime> _dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1).obs;
  final Rx<DateTime> _dateTo   = DateTime.now().obs;

  ProfitLossSummary? get summary  => _summary.value;
  bool get isLoading              => _isLoading.value;
  DateTime get dateFrom           => _dateFrom.value;
  DateTime get dateTo             => _dateTo.value;

  void setDateRange(DateTime from, DateTime to) {
    _dateFrom.value = from;
    _dateTo.value   = to;
    loadReport();
  }

  Future<void> loadReport() async {
    _isLoading.value = true;
    try {
      // Hitung dari lokal dulu (cepat)
      await _calcFromLocal();

      // Coba ambil dari backend jika online
      final hasNet = await _checkInternet();
      if (hasNet) await _fetchFromBackend();
    } catch (e) {
      print('❌ ProfitLossService.loadReport: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // ── Local Calculation ─────────────────────────────────────────────────────

  Future<void> _calcFromLocal() async {
    try {
      // viewBranchId: null = semua cabang (owner), non-null = cabang tertentu
      final branchId = _authService.viewBranchId.value;
      final fromStr  = DateFormat('yyyy-MM-dd').format(_dateFrom.value);
      final toStr    = DateFormat('yyyy-MM-dd').format(_dateTo.value);

      String branchWhere = branchId != null ? 'AND s.branch_id = $branchId' : '';

      // Penjualan
      final salesRows = await _db.rawQuery('''
        SELECT
          COUNT(*)                    AS total_transactions,
          COALESCE(SUM(s.subtotal),0) AS gross_sales,
          COALESCE(SUM(s.discount),0) AS total_discount,
          COALESCE(SUM(s.tax),0)      AS total_tax,
          COALESCE(SUM(s.total),0)    AS net_sales
        FROM sales s
        WHERE s.status = 'completed'
          AND substr(s.created_at,1,10) >= ?
          AND substr(s.created_at,1,10) <= ?
          $branchWhere
      ''', [fromStr, toStr]);

      final sr = salesRows.first;
      final grossSales     = _d(sr['gross_sales']);
      final totalDiscount  = _d(sr['total_discount']);
      final totalTax       = _d(sr['total_tax']);
      final netSales       = _d(sr['net_sales']);
      final totalTrx       = _i(sr['total_transactions']);

      // HPP = qty × products.cost via JOIN
      final hppRows = await _db.rawQuery('''
        SELECT COALESCE(SUM(si.quantity * p.cost), 0) AS hpp
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        JOIN products p ON p.id = si.product_id
        WHERE s.status = 'completed'
          AND substr(s.created_at,1,10) >= ?
          AND substr(s.created_at,1,10) <= ?
          $branchWhere
      ''', [fromStr, toStr]);

      final hpp = _d(hppRows.first['hpp']);

      // Pembelian stok
      String purchaseBranchWhere = branchId != null ? 'AND branch_id = $branchId' : '';
      final purchaseRows = await _db.rawQuery('''
        SELECT
          COUNT(*)                  AS total_count,
          COALESCE(SUM(total), 0)   AS total_amount
        FROM purchases
        WHERE status = 'received'
          AND substr(purchase_date,1,10) >= ?
          AND substr(purchase_date,1,10) <= ?
          $purchaseBranchWhere
      ''', [fromStr, toStr]);

      final pr            = purchaseRows.first;
      final totalPurchases = _d(pr['total_amount']);
      final purchaseCount  = _i(pr['total_count']);

      // Laba
      final grossProfit  = netSales - hpp;
      final grossMargin  = netSales > 0 ? grossProfit / netSales * 100 : 0.0;
      final netProfit    = grossProfit;
      final netMargin    = netSales > 0 ? netProfit / netSales * 100 : 0.0;

      // Breakdown metode bayar
      final payRows = await _db.rawQuery('''
        SELECT payment_method, COUNT(*) as cnt, COALESCE(SUM(total),0) as total
        FROM sales s
        WHERE s.status = 'completed'
          AND substr(s.created_at,1,10) >= ?
          AND substr(s.created_at,1,10) <= ?
          $branchWhere
        GROUP BY payment_method
        ORDER BY total DESC
      ''', [fromStr, toStr]);

      final paymentBreakdown = payRows.map((r) => PaymentBreakdownItem(
        method: r['payment_method'] as String? ?? 'cash',
        total:  _d(r['total']),
        count:  _i(r['cnt']),
      )).toList();

      // Top 5 produk
      final topRows = await _db.rawQuery('''
        SELECT si.product_name,
               SUM(si.quantity) AS qty,
               COALESCE(SUM(si.subtotal),0) AS revenue
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE s.status = 'completed'
          AND substr(s.created_at,1,10) >= ?
          AND substr(s.created_at,1,10) <= ?
          $branchWhere
        GROUP BY si.product_name
        ORDER BY revenue DESC
        LIMIT 5
      ''', [fromStr, toStr]);

      final topProducts = topRows.map((r) => TopProductItem(
        productName: r['product_name'] as String? ?? '-',
        qty:         _i(r['qty']),
        revenue:     _d(r['revenue']),
      )).toList();

      // Revenue harian
      final dailyRows = await _db.rawQuery('''
        SELECT substr(s.created_at,1,10) AS date,
               COALESCE(SUM(s.total),0) AS revenue,
               COUNT(*) AS transactions
        FROM sales s
        WHERE s.status = 'completed'
          AND substr(s.created_at,1,10) >= ?
          AND substr(s.created_at,1,10) <= ?
          $branchWhere
        GROUP BY substr(s.created_at,1,10)
        ORDER BY date ASC
      ''', [fromStr, toStr]);

      final dailyRevenue = dailyRows.map((r) => DailyRevenueItem(
        date:         r['date'] as String? ?? '',
        revenue:      _d(r['revenue']),
        transactions: _i(r['transactions']),
      )).toList();

      _summary.value = ProfitLossSummary(
        grossSales:        grossSales,
        totalDiscount:     totalDiscount,
        totalTax:          totalTax,
        netSales:          netSales,
        totalTransactions: totalTrx,
        hpp:               hpp,
        grossProfit:       grossProfit,
        grossMargin:       grossMargin,
        netProfit:         netProfit,
        netMargin:         netMargin,
        totalPurchases:    totalPurchases,
        totalPurchaseCount:purchaseCount,
        paymentBreakdown:  paymentBreakdown,
        topProducts:       topProducts,
        dailyRevenue:      dailyRevenue,
      );
    } catch (e) {
      print('❌ _calcFromLocal: $e');
    }
  }

  // ── Backend Fetch ─────────────────────────────────────────────────────────

  Future<void> _fetchFromBackend() async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;

      final branchId   = _authService.viewBranchId.value;
      final fromStr    = DateFormat('yyyy-MM-dd').format(_dateFrom.value);
      final toStr      = DateFormat('yyyy-MM-dd').format(_dateTo.value);
      final branchParam = branchId != null ? '&branch_id=$branchId' : '';

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reports/profit-loss?date_from=$fromStr&date_to=$toStr$branchParam'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data == null) return;

        final income   = data['income']   as Map<String, dynamic>? ?? {};
        final cogs     = data['cogs']     as Map<String, dynamic>? ?? {};
        final expenses = data['expenses'] as Map<String, dynamic>? ?? {};
        final profit   = data['profit']   as Map<String, dynamic>? ?? {};

        final dailyList = (data['daily'] as List<dynamic>? ?? []).map((d) {
          final m = d as Map<String, dynamic>;
          return DailyRevenueItem(
            date:         m['date'] as String? ?? '',
            revenue:      _d(m['revenue']),
            transactions: _i(m['transactions']),
          );
        }).toList();

        final payList = (data['payment_breakdown'] as List<dynamic>? ?? []).map((d) {
          final m = d as Map<String, dynamic>;
          return PaymentBreakdownItem(
            method: m['payment_method'] as String? ?? 'cash',
            total:  _d(m['total']),
            count:  _i(m['count']),
          );
        }).toList();

        final topList = (data['top_products'] as List<dynamic>? ?? []).map((d) {
          final m = d as Map<String, dynamic>;
          return TopProductItem(
            productName: m['product_name'] as String? ?? '-',
            qty:         _i(m['qty']),
            revenue:     _d(m['revenue']),
          );
        }).toList();

        _summary.value = ProfitLossSummary(
          grossSales:         _d(income['gross_sales']),
          totalDiscount:      _d(income['total_discount']),
          totalTax:           _d(income['total_tax']),
          netSales:           _d(income['net_sales']),
          totalTransactions:  _i(income['total_transactions']),
          hpp:                _d(cogs['hpp']),
          grossProfit:        _d(profit['gross_profit']),
          grossMargin:        _d(profit['gross_margin']),
          netProfit:          _d(profit['net_profit']),
          netMargin:          _d(profit['net_margin']),
          totalPurchases:     _d(expenses['total_purchases']),
          totalPurchaseCount: _i(expenses['total_purchase_count']),
          paymentBreakdown:   payList.isNotEmpty ? payList : (_summary.value?.paymentBreakdown ?? []),
          topProducts:        topList.isNotEmpty ? topList : (_summary.value?.topProducts ?? []),
          dailyRevenue:       dailyList.isNotEmpty ? dailyList : (_summary.value?.dailyRevenue ?? []),
        );
      }
    } catch (e) {
      print('❌ _fetchFromBackend: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _d(dynamic v, [double fb = 0.0]) {
    if (v == null) return fb;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  int _i(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fb;
  }

  Future<bool> _checkInternet() async {
    try {
      final r = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
