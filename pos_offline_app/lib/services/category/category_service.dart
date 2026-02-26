import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/database_tables.dart';
import '../../data/models/category_model.dart';
import '../../data/models/sync_queue_model.dart';
import '../auth/auth_service.dart';
import '../database/database_helper.dart';
import '../sync/sync_service.dart';

class CategoryService extends GetxService {
  final DatabaseHelper _db          = DatabaseHelper();
  final SyncService    _syncService = Get.find<SyncService>();
  AuthService get _auth             => Get.find<AuthService>();

  // Expose sebagai RxList agar controller bisa ever() subscribe
  final RxList<Category> categories = <Category>[].obs;
  final RxBool isLoading            = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  /// Load SEMUA kategori aktif dari local DB.
  /// Filter branch dilakukan secara in-memory di CategoryController._rebuildList().
  Future<void> loadCategories() async {
    isLoading.value = true;
    try {
      final results = await _db.query(
        DatabaseTables.categories,
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
      categories.value =
          results.map((m) => Category.fromDatabase(m)).toList();
    } catch (e) {
      _showError('Gagal memuat kategori: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Kategori merchant-level (berlaku semua branch)
  List<Category> get merchantCategories =>
      categories.where((c) => c.isMerchantLevel).toList();

  /// Semua kategori yang berlaku untuk branch tertentu
  List<Category> availableForBranch(int branchId) => categories
      .where((c) => c.isMerchantLevel || c.branchId == branchId)
      .toList();

  /// Tambah kategori baru (offline-first)
  Future<bool> addCategory(Category category) async {
    try {
      final merchantId = _auth.currentUser?.merchantId;

      final data = {
        if (merchantId != null) 'merchant_id': merchantId,
        if (category.branchId != null) 'branch_id':   category.branchId,
        if (category.branchName != null) 'branch_name': category.branchName,
        'name':        category.name,
        if (category.description != null) 'description': category.description,
        'is_active':   1,
        'created_at':  DateTime.now().toIso8601String(),
      };

      final localId = await _db.insert(DatabaseTables.categories, data);

      // Payload ke backend sudah termasuk merchant_id (backend juga ambil dari token)
      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.categories,
        operation: SyncOperation.create,
        recordId:  localId,
        data:      category.toApiPayload(),
      );

      await loadCategories();
      _showSuccess('Kategori "${category.name}" berhasil ditambahkan');
      return true;
    } catch (e) {
      _showError('Gagal menambah kategori: $e');
      return false;
    }
  }

  /// Update kategori (offline-first)
  Future<bool> updateCategory(Category category) async {
    try {
      final data = {
        if (category.branchId != null) 'branch_id':   category.branchId,
        // Kalau branch_id di-set null (merchant level), tetap update
        'branch_id':   category.branchId,
        if (category.branchName != null) 'branch_name': category.branchName,
        'name':        category.name,
        'description': category.description,
        'is_active':   category.isActive ? 1 : 0,
        'updated_at':  DateTime.now().toIso8601String(),
      };

      await _db.update(
        DatabaseTables.categories,
        data,
        where:     'id = ?',
        whereArgs: [category.id],
      );

      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.categories,
        operation: SyncOperation.update,
        recordId:  category.id,
        data:      category.toApiPayload(),
      );

      await loadCategories();
      _showSuccess('Kategori "${category.name}" berhasil diupdate');
      return true;
    } catch (e) {
      _showError('Gagal update kategori: $e');
      return false;
    }
  }

  /// Hapus kategori — soft delete (is_active = 0)
  Future<bool> deleteCategory(int categoryId) async {
    try {
      // Cari nama dulu untuk notifikasi
      final found = categories.firstWhereOrNull((c) => c.id == categoryId);

      await _db.update(
        DatabaseTables.categories,
        {
          'is_active':  0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where:     'id = ?',
        whereArgs: [categoryId],
      );

      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.categories,
        operation: SyncOperation.delete,
        recordId:  categoryId,
        data:      {'id': categoryId},
      );

      await loadCategories();
      _showSuccess('Kategori "${found?.name ?? ''}" berhasil dihapus',
          isDelete: true);
      return true;
    } catch (e) {
      _showError('Gagal hapus kategori: $e');
      return false;
    }
  }

  // ── Helpers snackbar ───────────────────────────────────────────────────

  void _showSuccess(String message, {bool isDelete = false}) {
    Get.snackbar(
      isDelete ? 'Dihapus' : 'Berhasil',
      message,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: isDelete ? Colors.orange.shade700 : Colors.green.shade600,
      colorText:       Colors.white,
      icon: Icon(
        isDelete ? Icons.delete_outline : Icons.check_circle_outline,
        color: Colors.white,
      ),
      margin:   const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }

  void _showError(String message) {
    Get.snackbar(
      'Gagal',
      message,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade600,
      colorText:       Colors.white,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      margin:   const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    );
  }
}
