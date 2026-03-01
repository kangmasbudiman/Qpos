class AppConstants {
  // API Configuration
  // ⚠️ GANTI URL INI SESUAI BACKEND ANDA
  
  // VPS Backend (Production/Staging)
  static const String baseUrlVPS = 'http://43.133.145.26:8081/api';
  
  // Development (Emulator - use 10.0.2.2 for Android emulator)
  static const String baseUrlEmulator = 'http://10.0.2.2:8001/api';
  
  // Development (Physical Device - use your computer's local IP)
  static const String baseUrlDevice = 'http://10.165.131.30:8001/api';
  
  // Production (HTTPS)
  static const String baseUrlProduction = 'https://api.yourapp.com/api';
  
  // Active URL - GANTI INI untuk switch environment
  static const String baseUrl = baseUrlVPS; // <-- NOW USING VPS BACKEND ✓
  
  static const String connectTimeoutMs = '30000';
  static const String receiveTimeoutMs = '30000';
  
  // Database Configuration
  static const String databaseName = 'pos_offline.db';
  static const int databaseVersion = 8;
  
  // Sync Configuration
  static const int syncIntervalMinutes = 5;
  static const int maxRetryAttempts = 3;
  static const int batchSyncSize = 50;
  
  // Storage Keys
  static const String authTokenKey      = 'auth_token';
  static const String userDataKey       = 'user_data';
  static const String lastSyncKey       = 'last_sync_time';
  static const String syncIntervalKey   = 'sync_interval_minutes';
  static const String themeModeKey      = 'theme_mode';
  static const String languageKey       = 'app_language';

  // Pilihan interval (menit) yang tersedia di UI
  static const List<int> syncIntervalOptions = [1, 2, 5, 10, 15, 30, 60];
  
  // Offline Status
  static const String offlineMode = 'offline_mode';
  static const String pendingSyncCount = 'pending_sync_count';
}