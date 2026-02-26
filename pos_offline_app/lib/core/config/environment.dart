/// Environment configuration for different build modes
enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.development;
  
  static Environment get current => _currentEnvironment;
  
  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }
  
  /// Get base URL based on current environment
  static String get baseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        // VPS Backend for development/testing
        return 'http://43.133.145.26:8081/api';
      
      case Environment.staging:
        // VPS Backend for staging
        return 'http://43.133.145.26:8081/api';
      
      case Environment.production:
        // VPS Backend for production
        return 'http://43.133.145.26:8081/api';
    }
  }
  
  /// Check if current environment is development
  static bool get isDevelopment => _currentEnvironment == Environment.development;
  
  /// Check if current environment is production
  static bool get isProduction => _currentEnvironment == Environment.production;
}
