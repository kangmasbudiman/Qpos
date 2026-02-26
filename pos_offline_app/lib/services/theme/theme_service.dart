import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

class ThemeService extends GetxService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  /// Dipanggil sekali sebelum app render agar theme sudah siap
  Future<void> loadFromStorage() => _loadTheme();

  Future<void> _loadTheme() async {
    try {
      final saved = await _storage.read(key: AppConstants.themeModeKey);
      isDarkMode.value = saved == 'dark';
    } catch (e) {
      debugPrint('ThemeService: error loading theme - $e');
      isDarkMode.value = false;
    }
  }

  Future<void> toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    await _storage.write(
      key: AppConstants.themeModeKey,
      value: isDarkMode.value ? 'dark' : 'light',
    );
  }

  Future<void> setDarkMode(bool value) async {
    if (isDarkMode.value == value) return;
    isDarkMode.value = value;
    await _storage.write(
      key: AppConstants.themeModeKey,
      value: value ? 'dark' : 'light',
    );
  }

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;
}
