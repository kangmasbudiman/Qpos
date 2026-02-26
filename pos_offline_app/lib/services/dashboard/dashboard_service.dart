import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../../data/models/sync_queue_model.dart';

class DashboardService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = Get.find<AuthService>();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Dashboard statistics
  final RxDouble _todaySales = 0.0.obs;
  final RxInt _todayTransactions = 0.obs;
  final RxInt _pendingSync = 0.obs;
  final RxInt _activeProducts = 0.obs;
  final RxInt _lowStockProducts = 0.obs;
  final RxDouble _monthSales = 0.0.obs;
  final RxDouble _weekSales = 0.0.obs;

  // Recent activities
  final RxList<Map<String, dynamic>> _recentActivities = <Map<String, dynamic>>[].obs;

  // Weekly sales chart data — list 7 hari, tiap item: {date, label, total}
  final RxList<Map<String, dynamic>> _weeklySales = <Map<String, dynamic>>[].obs;

  // Loading states
  final RxBool _isLoading = false.obs;
  final RxBool _isSyncing = false.obs;

  // Getters
  double get todaySales => _todaySales.value;
  int get todayTransactions => _todayTransactions.value;
  int get pendingSync => _pendingSync.value;
  int get activeProducts => _activeProducts.value;
  int get lowStockProducts => _lowStockProducts.value;
  double get monthSales => _monthSales.value;
  double get weekSales => _weekSales.value;
  List<Map<String, dynamic>> get recentActivities => _recentActivities;
  List<Map<String, dynamic>> get weeklySales => _weeklySales;
  bool get isLoading => _isLoading.value;
  bool get isSyncing => _isSyncing.value;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  /// Load dashboard dari SQLite lokal saja (cepat, tidak hapus data)
  Future<void> loadDashboardData() async {
    _isLoading.value = true;
    try {
      await _loadFromLocal();
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sync penuh dari server: hapus lokal → ambil dari server → reload
  /// Dipanggil hanya saat user tekan tombol sync
  Future<void> syncFromServer() async {
    _isLoading.value = true;
    try {
      final hasInternet = await _checkInternet();
      if (hasInternet) {
        print('🌐 Online, full sync from backend...');
        await _syncLocalFromBackend();
      } else {
        print('📴 Offline mode, using local data');
        await _loadFromLocal();
      }
    } catch (e) {
      print('❌ Error syncing from server: $e');
      await _loadFromLocal();
    } finally {
      _isLoading.value = false;
    }
  }

  /// Sync local database from backend data (full sync — hapus lokal lalu isi ulang dari server)
  Future<void> _syncLocalFromBackend() async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;

      // Gunakan viewBranchId (filter tampilan) bukan selectedBranch
      // agar saat owner pilih "Semua Cabang" → tarik semua data dari backend
      final viewBranchId = _authService.viewBranchId.value;

      print('🔄 Starting full sync from backend...');

      // Jika viewBranchId ada, filter per branch; jika null (semua cabang), ambil semua
      final branchParam = viewBranchId != null ? '&branch_id=$viewBranchId' : '';
      final url = '${AppConstants.baseUrl}/sales?per_page=500$branchParam';
      print('🌐 Sync URL: $url');
      print('🔑 Token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body (200 chars): ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        // Laravel paginate() → response: { data: { data: [...], total: N, ... } }
        // Laravel collection  → response: { data: [...] }
        List<dynamic>? salesList;
        final raw = body['data'];
        print('📦 raw type: ${raw.runtimeType}');
        if (raw is List) {
          salesList = raw;
        } else if (raw is Map) {
          salesList = raw['data'] as List<dynamic>?;
          print('📦 paginated total: ${raw['total']}');
        }

        print('📦 salesList count: ${salesList?.length ?? 0}');

        // Hapus hanya data yang sudah disync (is_synced = 1), preserve data offline
        // Hapus sale_items dari sales yang is_synced dulu
        await _db.rawQuery('DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE is_synced = 1)');
        await _db.rawQuery('DELETE FROM sales WHERE is_synced = 1');
        print('🗑️ Cleared synced local sales & items');

        if (salesList != null && salesList.isNotEmpty) {
          print('📥 Inserting ${salesList.length} sales from backend');
          int inserted = 0;
          for (var saleData in salesList) {
            try {
              await _insertOrUpdateSale(saleData as Map<String, dynamic>);
              inserted++;
            } catch (e) {
              print('❌ Insert error for sale: $e | data: $saleData');
            }
          }
          print('✅ Full sync done: $inserted/${salesList.length} sales inserted');
        } else {
          print('ℹ️ Server has no sales data');
        }

        await _loadFromLocal();
      } else {
        print('⚠️ Backend returned status ${response.statusCode}');
        print('⚠️ Body: ${response.body}');
        await _loadFromLocal();
      }
    } catch (e, st) {
      print('❌ Error syncing from backend: $e');
      print('❌ Stack: $st');
      await _loadFromLocal();
    }
  }

  // Helper: parse nilai yang bisa berupa num atau String dari Laravel
  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Konversi string datetime dari backend (UTC) ke waktu lokal
  /// agar substr(created_at,1,10) menghasilkan tanggal yang benar di timezone lokal
  String _toLocalDateTimeStr(dynamic v) {
    if (v == null) return DateTime.now().toIso8601String();
    try {
      final raw = v.toString();
      final dt = DateTime.parse(raw);
      final local = dt.toLocal();
      print('🕐 datetime conv: "$raw" (isUtc=${dt.isUtc}) → "${local.toIso8601String()}" (local date: ${local.year}-${local.month.toString().padLeft(2,'0')}-${local.day.toString().padLeft(2,'0')})');
      return local.toIso8601String();
    } catch (_) {
      return v.toString();
    }
  }

  /// Insert or update single sale from backend
  Future<void> _insertOrUpdateSale(Map<String, dynamic> saleData) async {
    try {
      // Field 'paid' di Laravel = 'cash' di lokal
      // Field 'change' di Laravel = 'change_amount' di lokal
      // created_at dari backend adalah UTC → dikonversi ke lokal agar tanggal match
      final sale = {
        'id':             saleData['id'] as int,
        'invoice_number': saleData['invoice_number'] as String? ?? 'SYNC-${saleData['id']}',
        'branch_id':      _toIntOrNull(saleData['branch_id']),
        'customer_id':    _toIntOrNull(saleData['customer_id']),
        'subtotal':       _toDouble(saleData['subtotal']),
        'discount':       _toDouble(saleData['discount']),
        'tax':            _toDouble(saleData['tax']),
        'total':          _toDouble(saleData['total']),
        'cash':           _toDouble(saleData['paid'] ?? saleData['cash']),
        'change_amount':  _toDouble(saleData['change'] ?? saleData['change_amount']),
        'payment_method': saleData['payment_method'] as String? ?? 'cash',
        'status':         saleData['status'] as String? ?? 'completed',
        'notes':          saleData['notes'] as String?,
        'is_synced':      1,
        'synced_at':      DateTime.now().toIso8601String(),
        'created_at':     _toLocalDateTimeStr(saleData['created_at']),
        'updated_at':     _toLocalDateTimeStr(saleData['updated_at']),
      };

      await _db.insert('sales', sale);

      // Insert sale_items jika ada di response backend
      final items = saleData['items'];
      if (items is List && items.isNotEmpty) {
        // Hapus items lama untuk sale ini dulu
        await _db.rawQuery('DELETE FROM sale_items WHERE sale_id = ?', [saleData['id']]);
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          try {
            await _db.insert('sale_items', {
              'sale_id':      saleData['id'] as int,
              'product_id':   _toIntOrNull(item['product_id']) ?? 0,
              'product_name': (item['product_name'] ?? item['product']?['name'] ?? '-') as String,
              'price':        _toDouble(item['price']),
              'quantity':     _toIntOrNull(item['quantity']) ?? 0,
              'discount':     _toDouble(item['discount']),
              'subtotal':     _toDouble(item['subtotal']),
              'created_at':   _toLocalDateTimeStr(item['created_at']),
            });
          } catch (e) {
            print('❌ Error inserting sale_item: $e | data: $item');
          }
        }
      }
    } catch (e) {
      print('❌ Error inserting sale: $e');
    }
  }

  /// Load statistics from local database
  Future<void> _loadFromLocal() async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

      // Branch filter — null berarti semua cabang (owner mode)
      final viewBranchId = _authService.viewBranchId.value;
      final branchWhere  = viewBranchId != null ? ' AND branch_id = $viewBranchId' : '';

      // Today's sales
      final todaySalesList = await _db.rawQuery('''
        SELECT total, created_at FROM sales
        WHERE status = 'completed'
        AND substr(created_at, 1, 10) = ?
        $branchWhere
      ''', [todayStr]);

      print('📊 Today ($todayStr) sales count: ${todaySalesList.length}');

      _todaySales.value = todaySalesList.fold<double>(
        0,
        (sum, row) => sum + _toDouble(row['total']),
      );

      // Today's transactions count
      _todayTransactions.value = todaySalesList.length;

      // Active products count
      final products = await _db.query(
        'products',
        columns: ['id', 'local_stock', 'min_stock'],
        where: 'is_active = ?',
        whereArgs: [1],
      );

      _activeProducts.value = products.length;

      // Low stock products
      _lowStockProducts.value = products.where((p) {
        final stock = p['local_stock'] as int? ?? 0;
        final minStock = p['min_stock'] as int? ?? 0;
        return stock <= minStock && stock > 0;
      }).length;

      // Pending sync count
      final pendingCount = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue'
      );
      _pendingSync.value = pendingCount.first['count'] as int? ?? 0;

      // Recent activities (last 5 sales)
      final recentSales = await _db.rawQuery('''
        SELECT s.*, c.name as customer_name
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE 1=1 $branchWhere
        ORDER BY s.created_at DESC
        LIMIT 5
      ''');

      _recentActivities.value = recentSales.map((sale) => {
        'type': 'sale',
        'title': 'Transaksi #${sale['invoice_number'] ?? 'LOCAL'}',
        'subtitle': _formatDate(sale['created_at'] as String?),
        'amount': '+ ${_formatCurrency(_toDouble(sale['total']))}',
        'icon': Icons.point_of_sale_rounded,
        'color': const Color(0xFF4CAF50),
      }).toList();

      // Weekly sales chart — 7 hari terakhir per tanggal
      final dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
      final firstDay = days.first;
      final firstDayStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2,'0')}-${firstDay.day.toString().padLeft(2,'0')}';

      final weeklySalesRows = await _db.rawQuery('''
        SELECT substr(created_at, 1, 10) as sale_date, SUM(total) as total_sales
        FROM sales
        WHERE status = 'completed'
          AND substr(created_at, 1, 10) >= ?
          $branchWhere
        GROUP BY substr(created_at, 1, 10)
      ''', [firstDayStr]);

      final totalsMap = <String, double>{};
      for (final row in weeklySalesRows) {
        final dateKey = row['sale_date'] as String;
        totalsMap[dateKey] = _toDouble(row['total_sales']);
        print('📊 weekly: $dateKey → ${totalsMap[dateKey]}');
      }

      _weeklySales.value = days.map((d) {
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
        return {
          'date':    key,
          'label':   isToday ? 'Hari\nini' : dayLabels[d.weekday % 7],
          'total':   totalsMap[key] ?? 0.0,
          'isToday': isToday,
        };
      }).toList();

    } catch (e) {
      print('❌ Error loading local dashboard data: $e');
    }
  }

  /// Load statistics from backend API
  Future<void> _loadFromBackend() async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null || token.isEmpty) return;
      
      final branchId = _authService.selectedBranch?.id;
      if (branchId == null) return;
      
      // Get dashboard statistics from backend
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/dashboard/stats?branch_id=$branchId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final stats = data['data'] as Map<String, dynamic>?;
        
        if (stats != null) {
          // Update today's sales
          _todaySales.value = (stats['today_sales'] as num?)?.toDouble() ?? _todaySales.value;
          
          // Update today's transactions
          _todayTransactions.value = stats['today_transactions'] as int? ?? _todayTransactions.value;
          
          // Update month sales
          _monthSales.value = (stats['month_sales'] as num?)?.toDouble() ?? _monthSales.value;
          
          // Update week sales
          _weekSales.value = (stats['week_sales'] as num?)?.toDouble() ?? _weekSales.value;
          
          // Update active products
          _activeProducts.value = stats['active_products'] as int? ?? _activeProducts.value;
          
          // Update low stock products
          _lowStockProducts.value = stats['low_stock_products'] as int? ?? _lowStockProducts.value;
        }
      }
      
      // Get recent activities from backend
      await _loadRecentActivities(token, branchId);
      
    } catch (e) {
      print('❌ Error loading backend dashboard data: $e');
    }
  }

  /// Load recent activities from backend
  Future<void> _loadRecentActivities(String token, int branchId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/dashboard/recent?branch_id=$branchId&limit=5'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final activities = data['data'] as List<dynamic>?;
        
        if (activities != null && activities.isNotEmpty) {
          _recentActivities.value = activities.map((activity) => {
            'type': activity['type'] ?? 'sale',
            'title': activity['title'] ?? '',
            'subtitle': activity['subtitle'] ?? '',
            'amount': activity['amount'] ?? '',
            'icon': _getIconForType(activity['type'] ?? ''),
            'color': _getColorForType(activity['type'] ?? ''),
          }).toList();
        }
      }
    } catch (e) {
      print('❌ Error loading recent activities: $e');
    }
  }

  /// Force refresh data from backend
  Future<void> forceRefresh() async {
    _isSyncing.value = true;
    try {
      final hasInternet = await _checkInternet();
      if (hasInternet) {
        await _syncLocalFromBackend();
      } else {
        await _loadFromLocal();
      }
    } finally {
      _isSyncing.value = false;
    }
  }

  /// Check internet connection
  Future<bool> _checkInternet() async {
    try {
      final result = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 3));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  /// Format date
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return '';
    }
  }

  /// Get icon for activity type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'sale':
        return Icons.point_of_sale_rounded;
      case 'purchase':
        return Icons.local_shipping_rounded;
      case 'product':
        return Icons.inventory_2_rounded;
      case 'customer':
        return Icons.person_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  /// Get color for activity type
  Color _getColorForType(String type) {
    switch (type) {
      case 'sale':
        return const Color(0xFF4CAF50);
      case 'purchase':
        return const Color(0xFFFF6B35);
      case 'product':
        return const Color(0xFF2196F3);
      case 'customer':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF4CAF50);
    }
  }
}
