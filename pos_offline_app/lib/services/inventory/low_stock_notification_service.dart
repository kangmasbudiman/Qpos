import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/product_model.dart';
import '../inventory/inventory_service.dart';

/// Service yang memantau produk low stock dan menampilkan in-app notification.
/// Dipanggil setiap kali InventoryService.loadProducts() selesai.
class LowStockNotificationService extends GetxService {
  late InventoryService _inventoryService;

  final RxList<Product> lowStockProducts  = <Product>[].obs;
  final RxList<Product> outOfStockProducts = <Product>[].obs;
  final RxBool hasAlert = false.obs;

  // Mencegah notif yang sama muncul berulang dalam satu sesi
  final Set<int> _notifiedIds = {};

  @override
  void onInit() {
    super.onInit();
    _inventoryService = Get.find<InventoryService>();

    // Pantau perubahan di daftar produk
    ever(_inventoryService.products as RxList<Product>, (_) => _checkStock());

    // Cek pertama kali
    _checkStock();
  }

  void _checkStock() {
    final products = _inventoryService.products;

    lowStockProducts.value = products.where((p) {
      final stock = p.localStock ?? 0;
      return stock > 0 && stock <= p.minStock && p.isActive;
    }).toList();

    outOfStockProducts.value = products.where((p) {
      return (p.localStock ?? 0) == 0 && p.isActive;
    }).toList();

    hasAlert.value = lowStockProducts.isNotEmpty || outOfStockProducts.isNotEmpty;

    // Tampilkan snackbar untuk produk low stock yang belum pernah dinotifikasi
    _notifyNewLowStock();
  }

  void _notifyNewLowStock() {
    final newLow = lowStockProducts.where((p) => !_notifiedIds.contains(p.id)).toList();
    final newOut = outOfStockProducts.where((p) => !_notifiedIds.contains(p.id)).toList();

    if (newLow.isNotEmpty || newOut.isNotEmpty) {
      // Tandai sudah dinotifikasi
      for (final p in [...newLow, ...newOut]) {
        if (p.id != null) _notifiedIds.add(p.id!);
      }

      final total = newLow.length + newOut.length;
      String message;
      if (newOut.isNotEmpty && newLow.isNotEmpty) {
        message = '${newOut.length} produk habis, ${newLow.length} produk stok rendah';
      } else if (newOut.isNotEmpty) {
        message = '${newOut.length} produk stok habis';
      } else {
        message = '${newLow.length} produk stok rendah';
      }

      // Delay sedikit agar UI sudah siap
      Future.delayed(const Duration(milliseconds: 800), () {
        if (Get.isSnackbarOpen) return;
        Get.snackbar(
          'Peringatan Stok',
          message,
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFF59E0B),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
          mainButton: TextButton(
            onPressed: () {
              Get.back(); // tutup snackbar
              Get.toNamed('/stock-opname');
            },
            child: const Text('Lihat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      });
    }
  }

  /// Reset notifikasi (misalnya setelah user acknowledge)
  void resetNotifications() {
    _notifiedIds.clear();
    _checkStock();
  }

  int get totalAlertCount => lowStockProducts.length + outOfStockProducts.length;

  /// Widget badge untuk ditampilkan di menu/icon
  Widget buildBadge({required Widget child}) {
    return Obx(() {
      if (!hasAlert.value) return child;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                totalAlertCount > 99 ? '99+' : '$totalAlertCount',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    });
  }
}
