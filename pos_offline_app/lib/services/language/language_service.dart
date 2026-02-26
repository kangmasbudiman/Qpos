import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';

/// Menyimpan & menyediakan pilihan bahasa aplikasi (id / en).
class LanguageService extends GetxService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Locale aktif yang reaktif — 'id' atau 'en'
  final RxString locale = 'id'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLocale();
  }

  /// Dipanggil dari main.dart sebelum Get.put agar bahasa sudah siap sebelum render
  Future<void> loadFromStorage() => _loadLocale();

  Future<void> _loadLocale() async {
    try {
      final saved = await _storage.read(key: AppConstants.languageKey);
      final value = (saved == 'en') ? 'en' : 'id';
      locale.value = value;
      AppStrings.setLocale(value);
    } catch (_) {
      locale.value = 'id';
      AppStrings.setLocale('id');
    }
  }

  Future<void> setLocale(String value) async {
    final lang = (value == 'en') ? 'en' : 'id';
    if (locale.value == lang) return;
    locale.value = lang;
    AppStrings.setLocale(lang);
    await _storage.write(key: AppConstants.languageKey, value: lang);
  }

  Future<void> toggleLocale() async {
    await setLocale(locale.value == 'id' ? 'en' : 'id');
  }

  bool get isEnglish => locale.value == 'en';
  bool get isIndonesian => locale.value == 'id';

  /// Helper: teks label locale untuk UI
  String get localeLabel => locale.value == 'en' ? 'English' : 'Bahasa Indonesia';
}
