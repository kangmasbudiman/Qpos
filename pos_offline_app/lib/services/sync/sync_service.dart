import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';
import '../../core/utils/connectivity_utils.dart';
import '../../data/models/sync_queue_model.dart';
import '../auth/auth_service.dart' show AuthService;
import '../database/database_helper.dart';

class SyncService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  final RxBool _isSyncing = false.obs;
  final RxInt _pendingCount = 0.obs;
  final RxString _lastSyncTime = ''.obs;
  
  bool get isSyncing => _isSyncing.value;
  int get pendingCount => _pendingCount.value;
  RxInt get pendingCountRx => _pendingCount;
  String get lastSyncTime => _lastSyncTime.value;
  
  Timer? _periodicSyncTimer;

  @override
  void onInit() {
    super.onInit();
    _updatePendingCount();
    _loadLastSyncTime();
    _startPeriodicSync();
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    super.onClose();
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(
      Duration(minutes: AppConstants.syncIntervalMinutes),
      (_) => syncPendingData(),
    );
  }

  /// Add item to sync queue
  Future<void> addToSyncQueue({
    required String tableName,
    required SyncOperation operation,
    int? recordId,
    required Map<String, dynamic> data,
  }) async {
    final queueItem = SyncQueueItem(
      tableName: tableName,
      operation: operation,
      recordId: recordId,
      data: data,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _db.insert(DatabaseTables.syncQueue, {
      'table_name': queueItem.tableName,
      'operation': queueItem.operation.name,
      if (queueItem.recordId != null) 'record_id': queueItem.recordId,
      'data': jsonEncode(queueItem.data),
      'retry_count': queueItem.retryCount,
      'created_at': queueItem.createdAt,
    });

    await _updatePendingCount();
  }

  /// Sync all pending data to backend
  Future<void> syncPendingData() async {
    if (_isSyncing.value) return;

    // Cek koneksi SEBELUM set isSyncing — jika tidak ada, bail tanpa mengunci
    final hasConnection = await ConnectivityUtils.hasInternetConnection();
    if (!hasConnection) {
      Get.snackbar(
        'Tidak Ada Koneksi',
        'Periksa koneksi internet dan coba lagi',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade700,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 3),
      );
      return;
    }

    // Ambil token SEBELUM set isSyncing — jika tidak ada, bail tanpa mengunci
    final token = await _storage.read(key: AppConstants.authTokenKey);
    if (token == null || token.isEmpty) {
      Get.snackbar(
        'Sesi Berakhir',
        'Silakan login ulang untuk sinkronisasi',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 4),
      );
      return;
    }

    // Setelah semua pre-check lulus, baru kunci
    _isSyncing.value = true;

    try {
      final pendingItems = await _getPendingSyncItems();
      print('📤 Starting sync: ${pendingItems.length} items');

      int successCount = 0;
      for (final item in pendingItems) {
        try {
          await _syncSingleItem(item, token);
          await _removeSyncItem(item.id!);
          successCount++;
        } catch (e) {
          await _handleSyncError(item, e.toString());
        }
      }

      await _updateLastSyncTime();
      await _updatePendingCount();
      print('✅ Sync completed: $successCount/${pendingItems.length} items');

      // Refresh local_stock dari server setelah ada sale yang berhasil sync
      final hadSales = pendingItems.any((i) => i.tableName == DatabaseTables.sales);
      if (hadSales && successCount > 0) {
        try {
          if (Get.isRegistered<AuthService>()) {
            await Get.find<AuthService>().refreshProductsFromServer();
          }
        } catch (_) {}
      }

      final remaining = _pendingCount.value;
      Get.snackbar(
        'Sinkronisasi Selesai',
        remaining == 0
            ? '$successCount item berhasil dikirim ke server'
            : '$successCount berhasil, $remaining item masih pending',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: remaining == 0
            ? const Color(0xFF4CAF50)
            : Colors.orange.shade700,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 3),
      );

    } catch (e) {
      print('🔴 Sync failed: $e');
      Get.snackbar(
        'Sinkronisasi Gagal',
        'Terjadi kesalahan: ${e.toString().replaceAll('Exception: ', '')}',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 5),
      );
    } finally {
      // finally SELALU dijalankan — _isSyncing pasti di-reset
      _isSyncing.value = false;
    }
  }

  /// Get pending sync items from queue
  Future<List<SyncQueueItem>> _getPendingSyncItems() async {
    final results = await _db.query(
      DatabaseTables.syncQueue,
      orderBy: 'created_at ASC',
      limit: AppConstants.batchSyncSize,
    );

    return results.map((map) => SyncQueueItem.fromDatabase({
      ...map,
      'data': jsonDecode(map['data'] as String),
    })).toList();
  }

  /// Sync single item to backend
  Future<void> _syncSingleItem(SyncQueueItem item, String token) async {
    final url = _buildApiUrl(item.tableName, item.operation, item.recordId);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    print('🌐 Syncing to: $url');

    // Jika produk punya gambar lokal (bukan URL), upload terlebih dahulu
    Map<String, dynamic> data = Map<String, dynamic>.from(item.data);
    if (item.tableName == DatabaseTables.products &&
        item.operation != SyncOperation.delete) {
      final imagePath = data['image'] as String?;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          !imagePath.startsWith('http')) {
        final uploadedUrl = await _uploadImageFile(imagePath, token);
        if (uploadedUrl != null) {
          data['image'] = uploadedUrl;
        } else {
          // Gagal upload — jangan kirim path lokal ke server
          data.remove('image');
        }
      }
    }

    print('📦 Data: ${jsonEncode(data)}');
    print('🔑 Token: ${token.substring(0, 20)}...');

    http.Response response;

    switch (item.operation) {
      case SyncOperation.create:
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(data),
        );
        print('📡 Response status: ${response.statusCode}');
        print('📡 Response body: ${response.body}');
        break;

      case SyncOperation.update:
        response = await http.put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(data),
        );
        break;

      case SyncOperation.cancel:
        // Cancel menggunakan POST ke /{id}/cancel
        final cancelUrl = _buildApiUrl(item.tableName, SyncOperation.cancel, item.recordId);
        print('🔄 Cancel URL: $cancelUrl');
        response = await http.post(
          Uri.parse(cancelUrl),
          headers: headers,
          body: jsonEncode(data),
        );
        break;

      case SyncOperation.delete:
        response = await http.delete(Uri.parse(url), headers: headers);
        break;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMsg = 'HTTP ${response.statusCode}: ${response.body}';
      print('❌ Sync Error: $errorMsg');

      // Handle duplicate entry error (HTTP 500)
      if (response.statusCode == 500 &&
          item.tableName == DatabaseTables.sales) {
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          final message = errBody['message'] as String? ?? '';
          
          // Check if it's a duplicate entry error
          if (message.contains('Duplicate entry') || 
              message.contains('UNIQUE constraint failed')) {
            print('⚠️ Duplicate sale, marking as synced');
            
            // Mark as synced and remove from queue
            await _markRecordAsSynced(item.tableName, item.recordId);
            await _removeSyncItem(item.id!);
            return; // Don't retry
          }
        } catch (e) {
          print('⚠️ Could not parse error response: $e');
        }
      }

      // Jika server tolak sale karena stok habis (422) → tandi sale sebagai sync_failed
      // agar tidak retry terus-menerus dan kasir bisa tahu
      if (response.statusCode == 422 &&
          item.tableName == DatabaseTables.sales &&
          item.recordId != null) {
        try {
          final errBody  = jsonDecode(response.body) as Map<String, dynamic>;
          final errMsg   = errBody['message'] as String? ?? 'Stok tidak mencukupi';
          await _db.update(
            DatabaseTables.sales,
            {
              'status':     'sync_failed',
              'notes':      '[SYNC GAGAL] $errMsg',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [item.recordId],
          );
          Get.snackbar(
            'Transaksi Gagal Sync',
            errMsg,
            duration:        const Duration(seconds: 6),
            backgroundColor: Colors.red.shade700,
            colorText:       Colors.white,
            snackPosition:   SnackPosition.TOP,
            margin:          const EdgeInsets.all(12),
            icon:            const Icon(Icons.warning_rounded, color: Colors.white),
          );
          // Hapus dari queue — tidak perlu retry karena server sudah tolak
          return;
        } catch (_) {}
      }

      Get.snackbar(
        '❌ Sync Failed',
        'Status ${response.statusCode} for ${item.tableName}',
        duration: Duration(seconds: 5),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      throw Exception(errorMsg);
    }

    print('✅ Successfully synced ${item.tableName} #${item.recordId}');

    // Tabel stocks tidak ada di SQLite lokal — cukup hapus dari sync queue
    if (item.tableName == DatabaseTables.stocks) {
      return;
    }

    // Untuk operasi create: update local ID dengan server ID dari response
    if (item.operation == SyncOperation.create && item.recordId != null) {
      try {
        final respBody = jsonDecode(response.body) as Map<String, dynamic>;
        final serverData = respBody['data'] as Map<String, dynamic>?;
        final serverId = serverData?['id'] as int?;
        if (serverId != null && serverId != item.recordId) {
          await _updateLocalId(item.tableName, item.recordId!, serverId);
          print('🔄 Updated local ID ${item.recordId} → server ID $serverId');
          return; // _updateLocalId sudah menandai is_synced=1
        }
      } catch (e) {
        print('⚠️ Could not parse server ID from response: $e');
      }
    }

    // Update local record as synced
    await _markRecordAsSynced(item.tableName, item.recordId);
  }

  /// Ganti local ID dengan server ID setelah create sync berhasil
  Future<void> _updateLocalId(
      String tableName, int localId, int serverId) async {
    final now = DateTime.now().toIso8601String();
    // Untuk tabel yang mendukung UPDATE id (SQLite mengizinkan ini)
    await _db.update(
      tableName,
      {
        'id':        serverId,
        'is_synced': 1,
        'synced_at': now,
      },
      where:     'id = ?',
      whereArgs: [localId],
    );
    // Update foreign key di sync queue jika ada item lain yang merujuk local ID ini
    await _db.update(
      DatabaseTables.syncQueue,
      {'record_id': serverId},
      where:     'table_name = ? AND record_id = ?',
      whereArgs: [tableName, localId],
    );
  }

  /// Upload gambar file lokal ke server, return URL publik atau null jika gagal
  Future<String?> _uploadImageFile(String localPath, String token) async {
    try {
      final file = io.File(localPath);
      if (!file.existsSync()) return null;

      final uri = Uri.parse('${AppConstants.baseUrl}/upload/image');
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';
      req.fields['folder'] = 'products';
      req.files.add(await http.MultipartFile.fromPath(
        'file',
        localPath,
        filename: localPath.split('/').last,
      ));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      if (streamed.statusCode == 201 && decoded['success'] == true) {
        print('🖼️ Image uploaded: ${decoded['url']}');
        return decoded['url'] as String;
      }
      print('❌ Image upload failed (${ streamed.statusCode}): $body');
      return null;
    } catch (e) {
      print('❌ Image upload error: $e');
      return null;
    }
  }

  /// Build API URL for sync operation
  String _buildApiUrl(String tableName, SyncOperation operation, int? recordId) {
    final baseUrl = AppConstants.baseUrl;
    
    switch (tableName) {
      case DatabaseTables.sales:
        return operation == SyncOperation.create 
            ? '$baseUrl/sales'
            : '$baseUrl/sales/$recordId';
      
      case DatabaseTables.products:
        return operation == SyncOperation.create 
            ? '$baseUrl/products'
            : '$baseUrl/products/$recordId';
      
      case DatabaseTables.customers:
        return operation == SyncOperation.create
            ? '$baseUrl/customers'
            : '$baseUrl/customers/$recordId';

      case DatabaseTables.categories:
        return operation == SyncOperation.create
            ? '$baseUrl/categories'
            : '$baseUrl/categories/$recordId';

      case DatabaseTables.stocks:
        // Stock adjustment selalu POST ke /stocks/adjustment
        return '$baseUrl/stocks/adjustment';

      case DatabaseTables.purchases:
        if (operation == SyncOperation.create) {
          return '$baseUrl/purchases';
        } else if (operation == SyncOperation.cancel) {
          return '$baseUrl/purchases/$recordId/cancel';
        } else {
          return '$baseUrl/purchases/$recordId';
        }

      default:
        throw Exception('Unknown table for sync: $tableName');
    }
  }

  /// Mark local record as synced
  Future<void> _markRecordAsSynced(String tableName, int? recordId) async {
    if (recordId == null) return;

    await _db.update(
      tableName,
      {
        'is_synced': 1,
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  /// Handle sync error and retry logic
  Future<void> _handleSyncError(SyncQueueItem item, String error) async {
    final newRetryCount = item.retryCount + 1;
    
    if (newRetryCount >= AppConstants.maxRetryAttempts) {
      print('🔴 Max retries reached for ${item.tableName}:${item.recordId}');
      await _removeSyncItem(item.id!);
    } else {
      await _db.update(
        DatabaseTables.syncQueue,
        {
          'retry_count': newRetryCount,
          'last_error': error,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
  }

  /// Remove sync item from queue
  Future<void> _removeSyncItem(int id) async {
    await _db.delete(
      DatabaseTables.syncQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update pending sync count
  Future<void> _updatePendingCount() async {
    final results = await _db.query(
      DatabaseTables.syncQueue,
      columns: ['COUNT(*) as count'],
    );
    _pendingCount.value = results.first['count'] as int;
  }

  /// Update last sync time
  Future<void> _updateLastSyncTime() async {
    final now = DateTime.now().toIso8601String();
    await _storage.write(key: AppConstants.lastSyncKey, value: now);
    _lastSyncTime.value = now;
  }

  /// Load last sync time from storage
  Future<void> _loadLastSyncTime() async {
    final lastSync = await _storage.read(key: AppConstants.lastSyncKey);
    _lastSyncTime.value = lastSync ?? '';
  }

  /// Force sync all unsynced data
  Future<void> forceSyncAll() async {
    print('🚀 Force sync all data...');
    await syncPendingData();
  }

  /// Clear all sync queue (use with caution)
  Future<void> clearSyncQueue() async {
    await _db.delete(DatabaseTables.syncQueue);
    await _updatePendingCount();
    print('🗑️ Sync queue cleared');
  }
}