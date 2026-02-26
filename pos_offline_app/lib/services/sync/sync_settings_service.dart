import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';

/// Menyimpan & menyediakan pengaturan sinkronisasi yang bisa diubah pengguna.
class SyncSettingsService extends GetxService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Interval sinkronisasi aktif (menit) — reaktif agar UI & timer bisa observe.
  final RxInt intervalMinutes = AppConstants.syncIntervalMinutes.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedInterval();
  }

  /// Dipanggil dari main.dart sebelum Get.put agar interval sudah terload
  /// sebelum AutoSyncService menggunakannya.
  Future<void> loadFromStorage() => _loadSavedInterval();

  Future<void> _loadSavedInterval() async {
    final saved = await _storage.read(key: AppConstants.syncIntervalKey);
    if (saved != null) {
      final parsed = int.tryParse(saved);
      if (parsed != null && AppConstants.syncIntervalOptions.contains(parsed)) {
        intervalMinutes.value = parsed;
      }
    }
  }

  /// Ubah interval & simpan ke storage. Kembalikan `true` jika berubah.
  Future<bool> setInterval(int minutes) async {
    if (!AppConstants.syncIntervalOptions.contains(minutes)) return false;
    if (intervalMinutes.value == minutes) return false;

    intervalMinutes.value = minutes;
    await _storage.write(
      key: AppConstants.syncIntervalKey,
      value: minutes.toString(),
    );
    return true;
  }

  /// Reset ke default bawaan aplikasi.
  Future<void> resetToDefault() async {
    await setInterval(AppConstants.syncIntervalMinutes);
  }

  /// Label yang ditampilkan di UI.
  String get intervalLabel {
    final m = intervalMinutes.value;
    if (m < 60) return '$m menit';
    return '${m ~/ 60} jam';
  }

  static String labelFor(int minutes) {
    if (minutes < 60) return '$minutes menit';
    return '${minutes ~/ 60} jam';
  }
}
