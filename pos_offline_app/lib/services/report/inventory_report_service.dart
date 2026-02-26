import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';

class InventoryReportItem {
  final int? id;
  final String productName;
  final String sku;
  final String? barcode;
  final String? categoryName;
  final double price;
  final double cost;
  final int localStock;
  final int minStock;
  final String unit;
  final double stockValue;
  final String stockStatus; // 'in_stock', 'low_stock', 'out_of_stock'
  final bool isActive;

  InventoryReportItem({
    this.id,
    required this.productName,
    required this.sku,
    this.barcode,
    this.categoryName,
    required this.price,
    required this.cost,
    required this.localStock,
    required this.minStock,
    required this.unit,
    required this.stockValue,
    required this.stockStatus,
    required this.isActive,
  });

  factory InventoryReportItem.fromDatabase(Map<String, dynamic> map) {
    final stock = map['local_stock'] as int? ?? 0;
    final minStock = map['min_stock'] as int? ?? 0;
    final cost = (map['cost'] as num?)?.toDouble() ?? 0.0;
    
    String stockStatus;
    if (stock <= 0) {
      stockStatus = 'out_of_stock';
    } else if (stock <= minStock) {
      stockStatus = 'low_stock';
    } else {
      stockStatus = 'in_stock';
    }

    return InventoryReportItem(
      id: map['id'] as int?,
      productName: map['name'] as String? ?? 'Unknown',
      sku: map['sku'] as String? ?? '-',
      barcode: map['barcode'] as String?,
      categoryName: map['category_name'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      cost: cost,
      localStock: stock,
      minStock: minStock,
      unit: map['unit'] as String? ?? 'pcs',
      stockValue: stock * cost,
      stockStatus: stockStatus,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}

class InventoryReportSummary {
  final int totalProducts;
  final int activeProducts;
  final int inStockProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final double totalStockValue;
  final double potentialRevenue;
  final Map<String, int> productsByCategory;

  InventoryReportSummary({
    required this.totalProducts,
    required this.activeProducts,
    required this.inStockProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.totalStockValue,
    required this.potentialRevenue,
    required this.productsByCategory,
  });
}

class InventoryReportService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = Get.find<AuthService>();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final RxList<InventoryReportItem> _reportItems = <InventoryReportItem>[].obs;
  final Rxn<InventoryReportSummary> _summary = Rxn<InventoryReportSummary>();
  final RxBool _isLoading = false.obs;

  // Filters
  final RxnInt _categoryId = RxnInt(); // null = all
  final RxString _stockStatus = ''.obs; // '', 'in_stock', 'low_stock', 'out_of_stock'
  final RxString _searchQuery = ''.obs;
  final RxBool _showLowStockOnly = false.obs;

  // Getters
  List<InventoryReportItem> get reportItems => _reportItems;
  InventoryReportSummary? get summary => _summary.value;
  bool get isLoading => _isLoading.value;
  int? get categoryId => _categoryId.value;
  String get stockStatus => _stockStatus.value;
  String get searchQuery => _searchQuery.value;
  bool get showLowStockOnly => _showLowStockOnly.value;

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  /// Set category filter
  void setCategory(int? id) {
    _categoryId.value = id;
    loadReport();
  }

  /// Set stock status filter
  void setStockStatus(String status) {
    _stockStatus.value = status;
    loadReport();
  }

  /// Toggle low stock only
  void toggleLowStockOnly() {
    _showLowStockOnly.value = !_showLowStockOnly.value;
    if (_showLowStockOnly.value) {
      _stockStatus.value = 'low_stock';
    } else {
      _stockStatus.value = '';
    }
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
      print('❌ Error loading inventory report: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Load from local database
  Future<void> _loadFromLocal() async {
    try {
      final branchId = _authService.selectedBranch?.id;
      
      // Build where clause
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];
      
      // Category filter
      if (_categoryId.value != null) {
        whereClause += ' AND p.category_id = ?';
        whereArgs.add(_categoryId.value);
      }
      
      // Stock status filter
      if (_stockStatus.value.isNotEmpty) {
        switch (_stockStatus.value) {
          case 'in_stock':
            whereClause += ' AND p.local_stock > p.min_stock';
            break;
          case 'low_stock':
            whereClause += ' AND p.local_stock > 0 AND p.local_stock <= p.min_stock';
            break;
          case 'out_of_stock':
            whereClause += ' AND p.local_stock <= 0';
            break;
        }
      }
      
      // Low stock only quick filter
      if (_showLowStockOnly.value) {
        whereClause += ' AND p.local_stock > 0 AND p.local_stock <= p.min_stock';
      }
      
      // Search filter
      if (_searchQuery.value.isNotEmpty) {
        whereClause += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
        whereArgs.add('%${_searchQuery.value}%');
        whereArgs.add('%${_searchQuery.value}%');
        whereArgs.add('%${_searchQuery.value}%');
      }
      
      // Get products data
      final results = await _db.rawQuery('''
        SELECT 
          p.*,
          c.name as category_name,
          (p.local_stock * p.cost) as stock_value
        FROM products p
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE $whereClause
        ORDER BY p.name ASC
      ''', whereArgs);
      
      _reportItems.value = results.map((row) => 
          InventoryReportItem.fromDatabase(row)).toList();
      
      // Calculate summary
      _calculateSummary();
      
    } catch (e) {
      print('❌ Error loading local inventory report: $e');
      _reportItems.clear();
    }
  }

  /// Load from backend API
  Future<void> _loadFromBackend() async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;
      
      final branchId = _authService.selectedBranch?.id;
      if (branchId == null) return;
      
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reports/inventory?branch_id=$branchId&category_id=${_categoryId.value ?? ''}&stock_status=${_stockStatus.value}'),
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
            _summary.value = InventoryReportSummary(
              totalProducts: backendSummary['total_products'] as int? ?? _summary.value?.totalProducts ?? 0,
              activeProducts: backendSummary['active_products'] as int? ?? _summary.value?.activeProducts ?? 0,
              inStockProducts: backendSummary['in_stock_products'] as int? ?? _summary.value?.inStockProducts ?? 0,
              lowStockProducts: backendSummary['low_stock_products'] as int? ?? _summary.value?.lowStockProducts ?? 0,
              outOfStockProducts: backendSummary['out_of_stock_products'] as int? ?? _summary.value?.outOfStockProducts ?? 0,
              totalStockValue: (backendSummary['total_stock_value'] as num?)?.toDouble() ?? _summary.value?.totalStockValue ?? 0,
              potentialRevenue: (backendSummary['potential_revenue'] as num?)?.toDouble() ?? _summary.value?.potentialRevenue ?? 0,
              productsByCategory: Map<String, int>.from(backendSummary['products_by_category'] ?? {}),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error loading backend inventory report: $e');
    }
  }

  /// Calculate summary from local data
  void _calculateSummary() {
    if (_reportItems.isEmpty) {
      _summary.value = null;
      return;
    }
    
    int totalProducts = _reportItems.length;
    int activeProducts = _reportItems.where((p) => p.isActive).length;
    int inStockProducts = _reportItems.where((p) => p.stockStatus == 'in_stock').length;
    int lowStockProducts = _reportItems.where((p) => p.stockStatus == 'low_stock').length;
    int outOfStockProducts = _reportItems.where((p) => p.stockStatus == 'out_of_stock').length;
    
    double totalStockValue = _reportItems.fold<double>(
      0, 
      (sum, p) => sum + p.stockValue
    );
    
    double potentialRevenue = _reportItems.fold<double>(
      0, 
      (sum, p) => sum + ((p.price - p.cost) * p.localStock)
    );
    
    Map<String, int> productsByCategory = {};
    for (var item in _reportItems) {
      final catName = item.categoryName ?? 'Tanpa Kategori';
      productsByCategory[catName] = (productsByCategory[catName] ?? 0) + 1;
    }
    
    _summary.value = InventoryReportSummary(
      totalProducts: totalProducts,
      activeProducts: activeProducts,
      inStockProducts: inStockProducts,
      lowStockProducts: lowStockProducts,
      outOfStockProducts: outOfStockProducts,
      totalStockValue: totalStockValue,
      potentialRevenue: potentialRevenue,
      productsByCategory: productsByCategory,
    );
  }

  /// Reset filters
  void resetFilters() {
    _categoryId.value = null;
    _stockStatus.value = '';
    _searchQuery.value = '';
    _showLowStockOnly.value = false;
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
