import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/connectivity_utils.dart';
import 'sync_service.dart';
import 'sync_settings_service.dart';

class AutoSyncService extends GetxService {
  final SyncService         _syncService  = Get.find<SyncService>();
  final SyncSettingsService _syncSettings = Get.find<SyncSettingsService>();

  Timer? _syncTimer;

  final RxBool       _isAutoSyncEnabled    = true.obs;
  final RxBool       _isAutoSyncActive     = false.obs;
  final Rx<DateTime> _lastAutoSync         = DateTime.now().obs;
  final RxInt        _autoSyncSuccessCount = 0.obs;
  final RxInt        _autoSyncFailureCount = 0.obs;

  // Rx getters — dipakai Obx di UI
  RxBool       get isAutoSyncEnabledRx    => _isAutoSyncEnabled;
  RxBool       get isAutoSyncActiveRx     => _isAutoSyncActive;
  RxInt        get autoSyncSuccessCountRx => _autoSyncSuccessCount;
  RxInt        get autoSyncFailureCountRx => _autoSyncFailureCount;
  Rx<DateTime> get lastAutoSyncRx         => _lastAutoSync;

  bool     get isAutoSyncEnabled    => _isAutoSyncEnabled.value;
  bool     get isAutoSyncActive     => _isAutoSyncActive.value;
  DateTime get lastAutoSync         => _lastAutoSync.value;
  int      get autoSyncSuccessCount => _autoSyncSuccessCount.value;
  int      get autoSyncFailureCount => _autoSyncFailureCount.value;

  @override
  void onInit() {
    super.onInit();
    _startAutoSync();

    // Restart timer otomatis setiap kali pengguna mengubah interval
    ever(_syncSettings.intervalMinutes, (_) {
      if (_isAutoSyncEnabled.value) _restartAutoSync();
    });
  }

  @override
  void onClose() {
    _stopAutoSync();
    super.onClose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startAutoSync() {
    if (_syncTimer?.isActive ?? false) return;

    _syncTimer = Timer.periodic(
      Duration(minutes: _syncSettings.intervalMinutes.value),
      (_) => _performAutoSync(),
    );
    _isAutoSyncActive.value = true;
  }

  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isAutoSyncActive.value = false;
  }

  void _restartAutoSync() {
    _stopAutoSync();
    _startAutoSync();
  }

  // ── Core sync ──────────────────────────────────────────────────────────────

  Future<void> _performAutoSync() async {
    if (!_isAutoSyncEnabled.value) return;

    try {
      final hasConnection = await ConnectivityUtils.hasInternetConnection();
      if (!hasConnection) return;

      if (_syncService.pendingCount > 0) {
        await _syncService.syncPendingData();
        _autoSyncSuccessCount.value++;
        _lastAutoSync.value = DateTime.now();

        if (_syncService.pendingCount < 5) {
          Get.snackbar(
            'Sync Selesai',
            'Semua data berhasil dikirim ke server',
            snackPosition:   SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF4CAF50),
            colorText:       Colors.white,
            margin:          const EdgeInsets.all(12),
            duration:        const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      _autoSyncFailureCount.value++;
      Get.snackbar(
        'Sync Gagal',
        'Akan dicoba lagi secara otomatis',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 3),
      );
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Aktifkan / nonaktifkan auto sync.
  void setAutoSyncEnabled(bool enabled) {
    _isAutoSyncEnabled.value = enabled;
    if (enabled) {
      _startAutoSync();
      Get.snackbar('Auto Sync', 'Sinkronisasi otomatis diaktifkan',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12));
    } else {
      _stopAutoSync();
      Get.snackbar('Auto Sync', 'Sinkronisasi otomatis dinonaktifkan',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12));
    }
  }

  /// Ubah interval (menit) lalu restart timer.
  Future<void> changeInterval(int minutes) async {
    // SyncSettingsService menyimpan & reaktif → ever() di onInit() akan restart
    await _syncSettings.setInterval(minutes);
  }

  /// Paksa sync segera.
  Future<void> forceSync() async {
    await _performAutoSync();
  }

  /// Reset statistik.
  void resetStats() {
    _autoSyncSuccessCount.value = 0;
    _autoSyncFailureCount.value = 0;
    _lastAutoSync.value = DateTime.now();
  }

  /// Sync sesaat setelah koneksi kembali.
  void onConnectionRestored() {
    if (_isAutoSyncEnabled.value && _syncService.pendingCount > 0) {
      Timer(const Duration(seconds: 5), () async {
        await _performAutoSync();
      });
    }
  }

  /// Handle lifecycle app.
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isAutoSyncEnabled.value) {
          _restartAutoSync();
          Timer(const Duration(seconds: 2), () => _performAutoSync());
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  DateTime getNextSyncTime() =>
      lastAutoSync.add(Duration(minutes: _syncSettings.intervalMinutes.value));

  bool isSyncOverdue() => DateTime.now().isAfter(getNextSyncTime());

  Map<String, dynamic> getSyncStats() => {
        'isActive':     isAutoSyncActive,
        'lastSync':     lastAutoSync.toIso8601String(),
        'successCount': autoSyncSuccessCount,
        'failureCount': autoSyncFailureCount,
        'pendingItems': _syncService.pendingCount,
        'isEnabled':    _isAutoSyncEnabled.value,
        'intervalMin':  _syncSettings.intervalMinutes.value,
      };
}
