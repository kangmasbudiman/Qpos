import 'dart:async';
import 'package:get/get.dart';
import '../../core/utils/connectivity_utils.dart';
import '../../services/sync/sync_service.dart';

class ConnectivityController extends GetxController {
  final RxBool _isOnline = false.obs;
  final RxString _connectionType = 'none'.obs;
  
  bool get isOnline => _isOnline.value;
  String get connectionType => _connectionType.value;
  bool get isOffline => !_isOnline.value;
  
  StreamSubscription? _connectivitySubscription;
  late SyncService _syncService;

  @override
  void onInit() {
    super.onInit();
    _syncService = Get.find<SyncService>();
    _initConnectivity();
    _startListening();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  /// Initialize connectivity status
  Future<void> _initConnectivity() async {
    final isConnected = await ConnectivityUtils.hasInternetConnection();
    _updateConnectionStatus(isConnected);
  }

  /// Start listening to connectivity changes
  void _startListening() {
    _connectivitySubscription = ConnectivityUtils.connectivityStream.listen(
      (isConnected) {
        _updateConnectionStatus(isConnected);
        
        // Auto sync when coming back online
        if (isConnected && _syncService.pendingCount > 0) {
          _syncService.syncPendingData();
        }
      },
    );
  }

  /// Update connection status
  void _updateConnectionStatus(bool isConnected) {
    final wasOffline = isOffline;
    _isOnline.value = isConnected;
    _connectionType.value = isConnected ? 'connected' : 'none';
    
    // Show snackbar when connection changes
    if (wasOffline && isConnected) {
      Get.snackbar(
        '🟢 Connected',
        'Internet connection restored',
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 2),
      );
    } else if (!wasOffline && !isConnected) {
      Get.snackbar(
        '🔴 Offline',
        'Working in offline mode',
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 3),
      );
    }
  }

  /// Manually check connection
  Future<void> checkConnection() async {
    final isConnected = await ConnectivityUtils.hasInternetConnection();
    _updateConnectionStatus(isConnected);
  }

  /// Get connection status text for UI
  String getStatusText() {
    return isOnline ? 'Online' : 'Offline';
  }

  /// Get connection icon for UI
  String getStatusIcon() {
    return isOnline ? '🟢' : '🔴';
  }
}