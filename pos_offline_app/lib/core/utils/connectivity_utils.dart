import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityUtils {
  static final Connectivity _connectivity = Connectivity();
  static final InternetConnectionChecker _connectionChecker = 
      InternetConnectionChecker();

  /// Check if device has internet connection
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // If no connectivity at all, return false
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // If has connectivity, check actual internet access
      return await _connectionChecker.hasConnection;
    } catch (e) {
      return false;
    }
  }

  /// Get connectivity status stream
  static Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.asyncMap((_) async {
      return await hasInternetConnection();
    });
  }

  /// Check connection with custom timeout
  static Future<bool> hasInternetConnectionWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final checker = InternetConnectionChecker.createInstance(
        checkTimeout: timeout,
        checkInterval: const Duration(seconds: 1),
      );
      return await checker.hasConnection;
    } catch (e) {
      return false;
    }
  }
}