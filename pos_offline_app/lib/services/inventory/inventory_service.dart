import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/database_tables.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sync_queue_model.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../sync/sync_service.dart';

class InventoryService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = Get.find<SyncService>();
  
  final RxList<Product> _products = <Product>[].obs;
  final RxList<Product> _lowStockProducts = <Product>[].obs;
  final RxBool _isLoading = false.obs;
  
  List<Product> get products => _products;
  List<Product> get lowStockProducts => _lowStockProducts;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  /// Load all active products from local database
  Future<void> loadProducts() async {
    _isLoading.value = true;
    try {
      final results = await _db.query(
        DatabaseTables.products,
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );

      _products.value = results.map((map) => Product.fromDatabase(map)).toList();
      _updateLowStockProducts();
    } catch (e) {
      print('Error loading products: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Update low stock products list
  void _updateLowStockProducts() {
    _lowStockProducts.value = _products.where((product) {
      final currentStock = product.localStock ?? 0;
      return currentStock <= product.minStock && product.isActive;
    }).toList();
  }

  /// Build snake_case payload untuk dikirim ke backend API
  Map<String, dynamic> _toApiPayload(Product product) {
    return {
      if (product.merchantId != null) 'merchant_id': product.merchantId,
      if (product.categoryId != null) 'category_id': product.categoryId,
      'name':        product.name,
      'sku':         product.sku,
      if (product.barcode != null) 'barcode': product.barcode,
      if (product.description != null) 'description': product.description,
      'price':       product.price,
      'cost':        product.cost,
      'unit':        product.unit,
      'min_stock':   product.minStock,
      if (product.image != null) 'image': product.image,
      'is_active':   product.isActive,
      'stock':       product.localStock ?? 0,
    };
  }

  /// Add new product (offline-first)
  Future<bool> addProduct(Product product) async {
    try {
      // Insert to local database first
      final productData = product.toDatabase();
      productData.remove('id'); // Remove ID to auto-generate
      productData['created_at'] = DateTime.now().toIso8601String();
      productData['is_synced'] = 0; // Mark as not synced

      final localId = await _db.insert(DatabaseTables.products, productData);

      // Add to sync queue — kirim snake_case ke backend
      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.products,
        operation: SyncOperation.create,
        recordId: localId,
        data: _toApiPayload(product),
      );

      await loadProducts(); // Refresh list
      Get.snackbar('Berhasil', 'Produk berhasil ditambahkan');
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Gagal menambah produk: $e');
      return false;
    }
  }

  /// Update product (offline-first)
  Future<bool> updateProduct(Product product) async {
    try {
      final productData = product.toDatabase();
      productData['updated_at'] = DateTime.now().toIso8601String();
      productData['is_synced'] = 0; // Mark as not synced

      await _db.update(
        DatabaseTables.products,
        productData,
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Add to sync queue — kirim snake_case ke backend
      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.products,
        operation: SyncOperation.update,
        recordId: product.id,
        data: _toApiPayload(product),
      );

      await loadProducts(); // Refresh list
      Get.snackbar('Success', 'Product updated successfully');
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to update product: $e');
      return false;
    }
  }

  /// Delete product (offline-first)
  Future<bool> deleteProduct(int productId) async {
    try {
      await _db.update(
        DatabaseTables.products,
        {
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Add to sync queue
      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.products,
        operation: SyncOperation.delete,
        recordId: productId,
        data: {'id': productId},
      );

      await loadProducts(); // Refresh list
      Get.snackbar('Success', 'Product deleted successfully');
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete product: $e');
      return false;
    }
  }

  /// Update product stock
  Future<bool> updateStock(int productId, int newStock, {String? reason}) async {
    try {
      final currentProduct = _products.firstWhere((p) => p.id == productId);
      final oldStock = currentProduct.localStock ?? 0;
      final notes = reason ?? 'Penyesuaian stok manual';

      // Update stok di local database
      await _db.update(
        DatabaseTables.products,
        {
          'local_stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Record stock movement lokal
      await _recordStockMovement(
        productId: productId,
        oldStock: oldStock,
        newStock: newStock,
        reason: notes,
      );

      // Tambahkan ke sync queue — kirim ke POST /api/stocks/adjustment
      final branchId = Get.find<AuthService>().selectedBranch?.id;
      if (branchId != null) {
        await _syncService.addToSyncQueue(
          tableName: DatabaseTables.stocks,
          operation: SyncOperation.create,
          recordId: productId,
          data: {
            'product_id': productId,
            'branch_id': branchId,
            'quantity': newStock,
            'notes': notes,
          },
        );
      }

      await loadProducts(); // Refresh list
      Get.snackbar(
        'Stok Diperbarui',
        'Stok berhasil diubah dari $oldStock → $newStock',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF7C3AED),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Gagal mengubah stok: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return false;
    }
  }

  /// Record stock movement for audit trail
  Future<void> _recordStockMovement({
    required int productId,
    required int oldStock,
    required int newStock,
    required String reason,
  }) async {
    try {
      await _db.insert(DatabaseTables.stockMovements, {
        'product_id': productId,
        'type': 'adjustment',
        'quantity': newStock - oldStock,
        'quantity_before': oldStock,
        'quantity_after': newStock,
        'reference_type': 'manual',
        'notes': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error recording stock movement: $e');
    }
  }

  /// Bulk update stocks
  Future<bool> bulkUpdateStock(Map<int, int> stockUpdates) async {
    try {
      for (final entry in stockUpdates.entries) {
        await updateStock(entry.key, entry.value, reason: 'Bulk adjustment');
      }
      
      Get.snackbar('Success', 'Bulk stock update completed');
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Bulk update failed: $e');
      return false;
    }
  }

  /// Get product by barcode
  Product? getProductByBarcode(String barcode) {
    try {
      return _products.firstWhere(
        (product) => product.barcode == barcode && product.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get product by SKU
  Product? getProductBySKU(String sku) {
    try {
      return _products.firstWhere(
        (product) => product.sku == sku && product.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  /// Search products
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;
    
    final lowercaseQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
             product.sku.toLowerCase().contains(lowercaseQuery) ||
             (product.barcode?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Get products by category
  List<Product> getProductsByCategory(int categoryId) {
    return _products.where((product) => 
      product.categoryId == categoryId && product.isActive
    ).toList();
  }

  /// Get inventory statistics
  Map<String, dynamic> getInventoryStats() {
    final totalProducts = _products.where((p) => p.isActive).length;
    final totalStock = _products
        .where((p) => p.isActive)
        .fold<int>(0, (sum, p) => sum + (p.localStock ?? 0));
    final lowStockCount = _lowStockProducts.length;
    final outOfStockCount = _products
        .where((p) => p.isActive && (p.localStock ?? 0) == 0)
        .length;

    return {
      'totalProducts': totalProducts,
      'totalStock': totalStock,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
      'averageStock': totalProducts > 0 ? (totalStock / totalProducts).toInt() : 0,
    };
  }

  /// Export inventory data (for reports)
  List<Map<String, dynamic>> exportInventoryData() {
    return _products.where((p) => p.isActive).map((product) => {
      'name': product.name,
      'sku': product.sku,
      'barcode': product.barcode ?? '',
      'price': product.price,
      'cost': product.cost,
      'stock': product.localStock ?? 0,
      'min_stock': product.minStock,
      'status': (product.localStock ?? 0) <= product.minStock ? 'Low Stock' : 'Normal',
    }).toList();
  }
}