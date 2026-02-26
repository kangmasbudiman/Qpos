import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/database_tables.dart';
import '../../data/models/branch_model.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/sync_queue_model.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../sync/sync_service.dart';

class PurchaseService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();

  final RxList<Purchase> _purchases = <Purchase>[].obs;
  final RxBool _isLoading = false.obs;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    loadPurchases();
  }

  // ─────────────────────────────────────────────────────────────
  //  PO NUMBER GENERATOR
  // ─────────────────────────────────────────────────────────────

  /// Generate PO number dengan format: PO/{BRANCH_CODE}/{YYYY}/{MM}/{0000}
  /// Jika branch tidak ada, gunakan: PO/LOCAL/{YYYY}/{MM}/{0000}
  Future<String> _generatePurchaseNumber(int? branchId) async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.toString().padLeft(5, '0').substring(5, 7); // '02'

    // Dapatkan branch code
    String branchCode = 'LOCAL';
    if (branchId != null) {
      final authService = Get.find<AuthService>();
      final branch = authService.branches.firstWhere(
        (b) => b.id == branchId,
        orElse: () => Branch(id: 0, merchantId: 0, name: 'LOCAL', code: 'LOCAL'),
      );
      branchCode = branch.code ?? 'LOCAL';
    }

    // Cari nomor urut terakhir dari database
    final results = await _db.rawQuery('''
      SELECT purchase_number FROM purchases 
      WHERE purchase_number LIKE ? 
      ORDER BY id DESC LIMIT 1
    ''', ['PO/$branchCode/$year/$month/%']);

    int nextNumber = 1;
    if (results.isNotEmpty) {
      final lastNumber = results.first['purchase_number'] as String?;
      if (lastNumber != null) {
        // Extract angka terakhir dari "PO/JKT/2026/02/0001"
        final parts = lastNumber.split('/');
        if (parts.length >= 5) {
          final lastDigit = int.tryParse(parts.last);
          if (lastDigit != null) {
            nextNumber = lastDigit + 1;
          }
        }
      }
    }

    // Format: PO/JKT/2026/02/0001
    return 'PO/$branchCode/$year/$month/${nextNumber.toString().padLeft(4, '0')}';
  }

  // ─────────────────────────────────────────────────────────────
  //  PURCHASES
  // ─────────────────────────────────────────────────────────────

  /// Load riwayat pembelian dari SQLite
  Future<void> loadPurchases() async {
    _isLoading.value = true;
    try {
      final rows = await _db.query(
        DatabaseTables.purchases,
        orderBy: 'created_at DESC',
        limit: 100,
      );

      final list = <Purchase>[];
      for (final row in rows) {
        final purchase = Purchase.fromDatabase(row);
        // Load items-nya juga
        final itemRows = await _db.query(
          DatabaseTables.purchaseItems,
          where: 'purchase_id = ?',
          whereArgs: [purchase.id],
        );
        final items = itemRows.map((r) => PurchaseItem.fromDatabase(r)).toList();
        list.add(Purchase(
          id:             purchase.id,
          purchaseNumber: purchase.purchaseNumber,
          merchantId:     purchase.merchantId,
          branchId:       purchase.branchId,
          supplierId:     purchase.supplierId,
          supplierName:   purchase.supplierName,
          purchaseDate:   purchase.purchaseDate,
          subtotal:       purchase.subtotal,
          discount:       purchase.discount,
          tax:            purchase.tax,
          total:          purchase.total,
          status:         purchase.status,
          notes:          purchase.notes,
          isSynced:       purchase.isSynced,
          syncedAt:       purchase.syncedAt,
          createdAt:      purchase.createdAt,
          updatedAt:      purchase.updatedAt,
          items:          items,
        ));
      }
      _purchases.value = list;
    } catch (e) {
      print('Error loading purchases: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Buat purchase baru (offline-first)
  Future<bool> createPurchase({
    required int? supplierId,
    required String supplierName,
    required String purchaseDate,
    required List<PurchaseItem> items,
    double discount = 0,
    double tax = 0,
    String? notes,
  }) async {
    if (items.isEmpty) {
      Get.snackbar(
        'Peringatan',
        'Tambahkan minimal satu produk',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText:       Colors.white,
      );
      return false;
    }

    try {
      final authService = Get.find<AuthService>();
      final branchId    = authService.selectedBranch?.id;
      final merchantId  = authService.currentUser?.merchantId;
      final now         = DateTime.now().toIso8601String();

      // Generate PO number otomatis
      final purchaseNumber = await _generatePurchaseNumber(branchId);

      // Hitung subtotal dari items
      final subtotal = items.fold<double>(0, (sum, i) => sum + i.subtotal);
      final total    = subtotal - discount + tax;

      // Insert purchase header ke SQLite
      final purchaseData = <String, dynamic>{
        if (merchantId != null) 'merchant_id': merchantId,
        if (branchId != null) 'branch_id': branchId,
        if (supplierId != null) 'supplier_id': supplierId,
        'purchase_number': purchaseNumber,
        'supplier_name': supplierName,
        'purchase_date': purchaseDate,
        'subtotal':      subtotal,
        'discount':      discount,
        'tax':           tax,
        'total':         total,
        'status':        'received',
        if (notes != null) 'notes': notes,
        'is_synced':     0,
        'created_at':    now,
      };

      final purchaseId = await _db.insert(DatabaseTables.purchases, purchaseData);

      // Insert setiap item
      for (final item in items) {
        await _db.insert(DatabaseTables.purchaseItems, {
          'purchase_id':  purchaseId,
          'product_id':   item.productId,
          'product_name': item.productName,
          'cost':         item.cost,
          'quantity':     item.quantity,
          'discount':     item.discount,
          'subtotal':     item.subtotal,
          'created_at':   now,
        });

        // Tambah local_stock produk
        await _addLocalStock(item.productId, item.quantity);
      }

      // Tambah ke sync queue
      final syncService = Get.find<SyncService>();
      await syncService.addToSyncQueue(
        tableName: DatabaseTables.purchases,
        operation: SyncOperation.create,
        recordId:  purchaseId,
        data: {
          if (branchId != null) 'branch_id': branchId,
          if (supplierId != null) 'supplier_id': supplierId,
          'purchase_number': purchaseNumber,
          'purchase_date': purchaseDate,
          'discount':      discount,
          'tax':           tax,
          if (notes != null) 'notes': notes,
          'items': items.map((i) => i.toApiJson()).toList(),
        },
      );

      await loadPurchases();

    
      return true;
    } catch (e) {
      print('Error creating purchase: $e');
      Get.snackbar(
        'Gagal',
        'Gagal menyimpan pembelian: $e',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
      );
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  CANCEL
  // ─────────────────────────────────────────────────────────────

  /// Batalkan PO:
  /// - Kurangi local_stock produk sebesar qty yang pernah ditambahkan
  /// - Catat stock_movement bertipe 'out' (reversal)
  /// - Update status purchase → 'cancelled'
  /// - Jika belum sync: hapus dari sync queue
  /// - Jika sudah sync: tambah entri sync update status ke server
  Future<bool> cancelPurchase(Purchase purchase) async {
    if (purchase.status == 'cancelled') return false;
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Rollback stok setiap item
      final items = purchase.items ?? [];
      for (final item in items) {
        await _removeLocalStock(
          productId: item.productId,
          qty:       item.quantity,
          note:      'Pembatalan PO ${purchase.purchaseNumber ?? purchase.id}',
        );
      }

      // 2. Update status purchase di SQLite
      await _db.update(
        DatabaseTables.purchases,
        {'status': 'cancelled', 'updated_at': now, 'is_synced': 0},
        where:     'id = ?',
        whereArgs: [purchase.id],
      );

      // 3. Sync
      final syncService = Get.find<SyncService>();
      if (!purchase.isSynced) {
        // Belum pernah ke server → hapus antrian create-nya agar tidak dikirim
        await _db.delete(
          DatabaseTables.syncQueue,
          where:     'table_name = ? AND record_id = ?',
          whereArgs: [DatabaseTables.purchases, purchase.id],
        );
      } else {
        // Sudah di server → kirim cancel via sync queue (POST /{id}/cancel)
        await syncService.addToSyncQueue(
          tableName: DatabaseTables.purchases,
          operation: SyncOperation.cancel,
          recordId:  purchase.id,
          data:      {},
        );
      }

      await loadPurchases();

      _showSuccess('PO berhasil dibatalkan dan stok telah dikembalikan');
      return true;
    } catch (e) {
      print('Error cancelling purchase: $e');
      _showError('Gagal membatalkan PO: $e');
      return false;
    }
  }

  /// Kurangi stok lokal produk (rollback saat PO dibatalkan)
  Future<void> _removeLocalStock({
    required int    productId,
    required int    qty,
    required String note,
  }) async {
    try {
      final rows = await _db.query(
        DatabaseTables.products,
        columns:   ['local_stock'],
        where:     'id = ?',
        whereArgs: [productId],
      );
      if (rows.isEmpty) return;

      final currentStock = (rows.first['local_stock'] as int? ?? 0);
      final newStock     = (currentStock - qty).clamp(0, 999999);

      await _db.update(
        DatabaseTables.products,
        {
          'local_stock': newStock,
          'updated_at':  DateTime.now().toIso8601String(),
          'is_synced':   0,
        },
        where:     'id = ?',
        whereArgs: [productId],
      );

      await _db.insert(DatabaseTables.stockMovements, {
        'product_id':      productId,
        'type':            'out',
        'quantity':        qty,
        'quantity_before': currentStock,
        'quantity_after':  newStock,
        'reference_type':  'purchase_cancel',
        'notes':           note,
        'created_at':      DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error removing local stock: $e');
    }
  }

  void _showSuccess(String msg) {
    Get.snackbar(
      'Berhasil', msg,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF4CAF50),
      colorText:       Colors.white,
      margin:          const EdgeInsets.all(12),
      duration:        const Duration(seconds: 3),
      borderRadius:    12,
    );
  }

  void _showError(String msg) {
    Get.snackbar(
      'Gagal', msg,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText:       Colors.white,
      margin:          const EdgeInsets.all(12),
      duration:        const Duration(seconds: 4),
      borderRadius:    12,
    );
  }

  /// Tambah stok lokal produk setelah pembelian
  Future<void> _addLocalStock(int productId, int qty) async {
    try {
      final rows = await _db.query(
        DatabaseTables.products,
        columns:   ['local_stock'],
        where:     'id = ?',
        whereArgs: [productId],
      );
      if (rows.isEmpty) return;

      final currentStock = (rows.first['local_stock'] as int? ?? 0);
      final newStock     = currentStock + qty;

      await _db.update(
        DatabaseTables.products,
        {
          'local_stock': newStock,
          'updated_at':  DateTime.now().toIso8601String(),
          'is_synced':   0,
        },
        where:     'id = ?',
        whereArgs: [productId],
      );

      // Catat stock movement
      await _db.insert(DatabaseTables.stockMovements, {
        'product_id':      productId,
        'type':            'in',
        'quantity':        qty,
        'quantity_before': currentStock,
        'quantity_after':  newStock,
        'reference_type':  'purchase',
        'notes':           'Penerimaan barang dari supplier',
        'created_at':      DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding local stock: $e');
    }
  }
}
