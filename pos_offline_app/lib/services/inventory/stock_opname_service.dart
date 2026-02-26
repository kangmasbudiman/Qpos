import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';
import '../../data/models/product_model.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../inventory/inventory_service.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class OpnameItem {
  final Product product;
  final int systemQty;
  int countedQty;
  String notes;

  OpnameItem({
    required this.product,
    required this.systemQty,
    required this.countedQty,
    this.notes = '',
  });

  int get variance => countedQty - systemQty;
  bool get hasVariance => variance != 0;
}

class StockOpnameSummary {
  final int id;
  final String opnameNumber;
  final String opnameDate;
  final String status;
  final String? notes;
  final int totalItems;
  final int itemsWithVariance;
  final String createdAt;

  StockOpnameSummary({
    required this.id,
    required this.opnameNumber,
    required this.opnameDate,
    required this.status,
    this.notes,
    required this.totalItems,
    required this.itemsWithVariance,
    required this.createdAt,
  });

  factory StockOpnameSummary.fromMap(Map<String, dynamic> m) {
    return StockOpnameSummary(
      id:                m['id'] as int,
      opnameNumber:      m['opname_number'] as String,
      opnameDate:        m['opname_date'] as String,
      status:            m['status'] as String? ?? 'completed',
      notes:             m['notes'] as String?,
      totalItems:        m['total_items'] as int? ?? 0,
      itemsWithVariance: m['items_with_variance'] as int? ?? 0,
      createdAt:         m['created_at'] as String,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class StockOpnameService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _auth = Get.find<AuthService>();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // State untuk session opname yang sedang berjalan
  final RxList<OpnameItem> opnameItems = <OpnameItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Riwayat opname
  final RxList<StockOpnameSummary> history = <StockOpnameSummary>[].obs;

  /// Mulai session opname baru: muat semua produk aktif dengan stok saat ini
  Future<void> startNewOpname() async {
    isLoading.value = true;
    try {
      final products = Get.find<InventoryService>().products;
      opnameItems.value = products.map((p) {
        final systemQty = p.localStock ?? 0;
        return OpnameItem(
          product: p,
          systemQty: systemQty,
          countedQty: systemQty, // default sama dengan sistem
        );
      }).toList();
    } finally {
      isLoading.value = false;
    }
  }

  /// Update jumlah hitung fisik untuk satu produk
  void updateCountedQty(int productId, int qty) {
    final idx = opnameItems.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      opnameItems[idx].countedQty = qty;
      opnameItems.refresh();
    }
  }

  /// Update catatan untuk satu produk
  void updateItemNotes(int productId, String notes) {
    final idx = opnameItems.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      opnameItems[idx].notes = notes;
      opnameItems.refresh();
    }
  }

  /// Simpan opname: tulis ke lokal DB, sync ke backend, update stok lokal
  Future<bool> saveOpname({String? notes}) async {
    if (opnameItems.isEmpty) return false;
    isSaving.value = true;
    try {
      final branchId  = _auth.selectedBranch?.id;
      final now       = DateTime.now();
      final dateStr   = DateFormat('yyyy-MM-dd').format(now);
      final opnameNum = 'OPN-${DateFormat('yyyyMMdd').format(now)}-${now.millisecondsSinceEpoch % 10000}';

      // 1. Simpan header opname lokal
      final opnameId = await _db.insert(DatabaseTables.stockOpnames, {
        'opname_number': opnameNum,
        'branch_id':     branchId,
        'opname_date':   dateStr,
        'status':        'completed',
        'notes':         notes,
        'is_synced':     0,
        'created_at':    now.toIso8601String(),
      });

      // 2. Simpan item & update stok lokal jika ada selisih
      for (final item in opnameItems) {
        await _db.insert(DatabaseTables.stockOpnameItems, {
          'stock_opname_id': opnameId,
          'product_id':      item.product.id,
          'product_name':    item.product.name,
          'system_qty':      item.systemQty,
          'counted_qty':     item.countedQty,
          'variance':        item.variance,
          'notes':           item.notes.isEmpty ? null : item.notes,
        });

        if (item.hasVariance && item.product.id != null) {
          await _db.update(
            DatabaseTables.products,
            {
              'local_stock': item.countedQty,
              'updated_at':  now.toIso8601String(),
              'is_synced':   0,
            },
            where: 'id = ?',
            whereArgs: [item.product.id],
          );
          // Catat stock movement lokal
          await _db.insert(DatabaseTables.stockMovements, {
            'product_id':      item.product.id,
            'type':            'adjustment',
            'quantity':        item.variance.abs(),
            'quantity_before': item.systemQty,
            'quantity_after':  item.countedQty,
            'reference_type':  'stock_opname',
            'notes':           'Stock opname: $opnameNum',
            'created_at':      now.toIso8601String(),
          });
        }
      }

      // 3. Coba sync ke backend
      await _syncToBackend(
        opnameNumber: opnameNum,
        branchId:     branchId,
        opnameDate:   dateStr,
        notes:        notes,
        localId:      opnameId,
      );

      // 4. Refresh produk & history
      await Get.find<InventoryService>().loadProducts();
      await loadHistory();

      opnameItems.clear();
      return true;
    } catch (e) {
      debugPrint('❌ StockOpnameService.saveOpname: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _syncToBackend({
    required String opnameNumber,
    required int? branchId,
    required String opnameDate,
    String? notes,
    required int localId,
  }) async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;

      final items = opnameItems.map((i) => {
        'product_id':  i.product.id,
        'counted_qty': i.countedQty,
        'notes':       i.notes.isEmpty ? null : i.notes,
      }).toList();

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/stock-opnames'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'branch_id':    branchId,
          'opname_date':  opnameDate,
          'notes':        notes,
          'items':        items,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        await _db.update(
          DatabaseTables.stockOpnames,
          {'is_synced': 1, 'synced_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    } catch (e) {
      debugPrint('⚠️ Opname sync gagal (akan dicoba lagi): $e');
    }
  }

  /// Muat riwayat opname dari lokal DB
  Future<void> loadHistory() async {
    try {
      final rows = await _db.rawQuery('''
        SELECT
          o.id, o.opname_number, o.opname_date, o.status, o.notes, o.created_at,
          COUNT(i.id)                          AS total_items,
          SUM(CASE WHEN i.variance != 0 THEN 1 ELSE 0 END) AS items_with_variance
        FROM ${DatabaseTables.stockOpnames} o
        LEFT JOIN ${DatabaseTables.stockOpnameItems} i ON i.stock_opname_id = o.id
        GROUP BY o.id
        ORDER BY o.created_at DESC
        LIMIT 30
      ''');
      history.value = rows.map(StockOpnameSummary.fromMap).toList();
    } catch (e) {
      debugPrint('❌ loadHistory: $e');
    }
  }

  /// Item yang memiliki selisih
  List<OpnameItem> get itemsWithVariance =>
      opnameItems.where((i) => i.hasVariance).toList();

  int get totalVarianceItems => itemsWithVariance.length;
}
