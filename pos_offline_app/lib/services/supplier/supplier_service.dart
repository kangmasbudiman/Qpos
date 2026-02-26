import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';
import '../../data/models/supplier_model.dart';
import '../database/database_helper.dart';

class SupplierService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final RxList<Supplier> _suppliers = <Supplier>[].obs;
  final RxBool _isLoading = false.obs;

  List<Supplier> get suppliers => _suppliers;
  RxBool get isLoading => _isLoading;

  @override
  void onInit() {
    super.onInit();
    loadSuppliers();
  }

  // ─────────────────────────────────────────────────────────────
  //  LOAD
  // ─────────────────────────────────────────────────────────────

  Future<void> loadSuppliers() async {
    _isLoading.value = true;
    try {
      final rows = await _db.query(
        DatabaseTables.suppliers,
        where:   'is_active = 1',
        orderBy: 'name ASC',
      );
      _suppliers.value =
          rows.map((r) => Supplier.fromDatabase(r)).toList();

      // Jika lokal kosong, tarik dari server
      if (_suppliers.isEmpty) {
        await fetchFromServer(silent: true);
      }
    } catch (e) {
      print('Error loading suppliers: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  FETCH FROM SERVER
  // ─────────────────────────────────────────────────────────────

  Future<bool> fetchFromServer({bool silent = false}) async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return false;

      final resp = await http.get(
        Uri.parse('${AppConstants.baseUrl}/suppliers?per_page=200'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final body    = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawData = body['data'];
        final List rawList =
            rawData is List ? rawData : (rawData['data'] as List? ?? []);

        // Hapus data lama lalu insert baru
        await _db.delete(DatabaseTables.suppliers);
        for (final raw in rawList) {
          final s = Supplier.fromJson(raw as Map<String, dynamic>);
          await _db.insert(DatabaseTables.suppliers, s.toDatabase());
        }

        await loadSuppliers();
        if (!silent) _showSuccess('Data supplier diperbarui dari server');
        return true;
      }
      if (!silent) _showError('Gagal mengambil data: ${resp.statusCode}');
      return false;
    } catch (e) {
      print('Error fetching suppliers: $e');
      if (!silent) _showError('Tidak dapat terhubung ke server');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  ADD
  // ─────────────────────────────────────────────────────────────

  Future<bool> addSupplier({
    required String name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
  }) async {
    _isLoading.value = true;
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) {
        _showError('Sesi berakhir, silakan login ulang');
        return false;
      }

      final resp = await http.post(
        Uri.parse('${AppConstants.baseUrl}/suppliers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'name':         name,
          if (companyName?.isNotEmpty == true) 'company_name': companyName,
          if (phone?.isNotEmpty == true)       'phone':        phone,
          if (email?.isNotEmpty == true)       'email':        email,
          if (address?.isNotEmpty == true)     'address':      address,
        }),
      );

      if (resp.statusCode == 201) {
        final body     = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawData  = body['data'] as Map<String, dynamic>;
        final supplier = Supplier.fromJson(rawData);
        await _db.insert(DatabaseTables.suppliers, supplier.toDatabase());
        await loadSuppliers();
        _showSuccess('"${supplier.displayName}" berhasil ditambahkan');
        return true;
      }

      final errBody = jsonDecode(resp.body) as Map<String, dynamic>;
      _showError(errBody['message'] as String? ?? 'Gagal menyimpan supplier');
      return false;
    } catch (e) {
      _showError('Gagal menyimpan: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  UPDATE
  // ─────────────────────────────────────────────────────────────

  Future<bool> updateSupplier(Supplier supplier) async {
    _isLoading.value = true;
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) {
        _showError('Sesi berakhir');
        return false;
      }

      final resp = await http.put(
        Uri.parse('${AppConstants.baseUrl}/suppliers/${supplier.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'name':         supplier.name,
          'company_name': supplier.companyName ?? '',
          'phone':        supplier.phone       ?? '',
          'email':        supplier.email       ?? '',
          'address':      supplier.address     ?? '',
          'is_active':    supplier.isActive,
        }),
      );

      if (resp.statusCode == 200) {
        final body    = jsonDecode(resp.body) as Map<String, dynamic>;
        final updated = Supplier.fromJson(body['data'] as Map<String, dynamic>);
        await _db.update(
          DatabaseTables.suppliers,
          updated.toDatabase(),
          where:     'id = ?',
          whereArgs: [updated.id],
        );
        await loadSuppliers();
        _showSuccess('"${supplier.displayName}" berhasil diperbarui');
        return true;
      }

      final errBody = jsonDecode(resp.body) as Map<String, dynamic>;
      _showError(errBody['message'] as String? ?? 'Gagal memperbarui');
      return false;
    } catch (e) {
      _showError('Gagal memperbarui: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  DELETE (soft via server)
  // ─────────────────────────────────────────────────────────────

  Future<bool> deleteSupplier(int id, String name) async {
    _isLoading.value = true;
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) {
        _showError('Sesi berakhir');
        return false;
      }

      final resp = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/suppliers/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
        },
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        // Hapus dari lokal
        await _db.update(
          DatabaseTables.suppliers,
          {'is_active': 0},
          where:     'id = ?',
          whereArgs: [id],
        );
        await loadSuppliers();
        _showSuccess('"$name" berhasil dihapus');
        return true;
      }

      final errBody = jsonDecode(resp.body) as Map<String, dynamic>;
      _showError(errBody['message'] as String? ?? 'Gagal menghapus');
      return false;
    } catch (e) {
      _showError('Gagal menghapus: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────

  void _showSuccess(String msg) {
    Get.snackbar(
      'Berhasil', msg,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF4CAF50),
      colorText:       Colors.white,
      margin:          const EdgeInsets.all(12),
      duration:        const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      borderRadius: 12,
    );
  }

  void _showError(String msg) {
    Get.snackbar(
      'Gagal', msg,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade600,
      colorText:       Colors.white,
      margin:          const EdgeInsets.all(12),
      duration:        const Duration(seconds: 4),
      borderRadius: 12,
    );
  }
}
