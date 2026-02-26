import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/connectivity_controller.dart';
import '../../services/sync/sync_service.dart';

/// Dot kecil di pojok - untuk dipakai di AppBar actions atau SafeArea overlay
class ConnectivityDot extends StatelessWidget {
  const ConnectivityDot({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityController>();
    final sync         = Get.find<SyncService>();

    return Obx(() {
      final isOnline     = connectivity.isOnline;
      final isSyncing    = sync.isSyncing;
      final pendingCount = sync.pendingCount;

      final color = isSyncing
          ? Colors.orange
          : isOnline
              ? (pendingCount > 0 ? Colors.blue : Colors.green)
              : Colors.red;

      final icon = isSyncing
          ? Icons.sync_rounded
          : isOnline
              ? Icons.wifi_rounded
              : Icons.wifi_off_rounded;

      return GestureDetector(
        onTap: () => _showStatusPopup(context, isOnline, isSyncing, pendingCount, sync),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:  color.withValues(alpha: 0.15),
                shape:  BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              ),
              child: isSyncing
                  ? _SyncSpinIcon(color: color)
                  : Icon(icon, color: color, size: 18),
            ),
            // Badge jumlah pending
            if (pendingCount > 0 && !isSyncing)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showStatusPopup(BuildContext context, bool isOnline, bool isSyncing,
      int pendingCount, SyncService sync) {
    final color = isSyncing
        ? Colors.orange
        : isOnline
            ? (pendingCount > 0 ? Colors.blue : Colors.green)
            : Colors.red;

    final statusText = isSyncing
        ? 'Sedang menyinkronkan data...'
        : isOnline
            ? (pendingCount > 0
                ? 'Online · $pendingCount data menunggu sync'
                : 'Online · Semua data tersinkron')
            : (pendingCount > 0
                ? 'Offline · $pendingCount data akan sync saat online'
                : 'Offline');

    showModalBottomSheet(
      context:       context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusBottomSheet(
        color:       color,
        statusText:  statusText,
        isOnline:    isOnline,
        isSyncing:   isSyncing,
        pendingCount: pendingCount,
        sync:        sync,
      ),
    );
  }
}

/// Spinning icon untuk saat sync
class _SyncSpinIcon extends StatefulWidget {
  final Color color;
  const _SyncSpinIcon({required this.color});

  @override
  State<_SyncSpinIcon> createState() => _SyncSpinIconState();
}

class _SyncSpinIconState extends State<_SyncSpinIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(Icons.sync_rounded, color: widget.color, size: 18),
    );
  }
}

/// Bottom sheet popup saat dot di-tap
class _StatusBottomSheet extends StatelessWidget {
  final Color  color;
  final String statusText;
  final bool   isOnline;
  final bool   isSyncing;
  final int    pendingCount;
  final SyncService sync;

  const _StatusBottomSheet({
    required this.color,
    required this.statusText,
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    required this.sync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Status icon + text
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: color, size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   16,
                        color:      color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tombol sync jika ada pending dan online
          if (isOnline && pendingCount > 0 && !isSyncing) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  sync.syncPendingData();
                },
                icon:  const Icon(Icons.sync_rounded, size: 18),
                label: Text('Sync Sekarang ($pendingCount data)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Widget lama - dijaga untuk backward compat, sekarang pakai ConnectivityDot
@Deprecated('Gunakan ConnectivityDot')
class ConnectivityIndicator extends StatelessWidget {
  final bool showDetails;
  final bool showSyncStatus;

  const ConnectivityIndicator({
    Key? key,
    this.showDetails    = false,
    this.showSyncStatus = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => const ConnectivityDot();
}

/// Untuk dipakai di AppBar actions
class ConnectivityAppBarAction extends StatelessWidget {
  const ConnectivityAppBarAction({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(child: ConnectivityDot()),
    );
  }
}

class FullConnectivityStatus extends StatelessWidget {
  const FullConnectivityStatus({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityController>();
    final sync         = Get.find<SyncService>();

    return Obx(() {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: connectivity.isOnline ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text('Connection Status',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              _statusRow('Status', connectivity.getStatusText()),
              _statusRow('Pending Sync', '${sync.pendingCount} items'),
              _statusRow('Last Sync', _formatLastSync(sync.lastSyncTime)),
              if (sync.isSyncing) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Syncing data...'),
                  ],
                ),
              ],
              if (connectivity.isOnline && sync.pendingCount > 0) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => sync.syncPendingData(),
                  icon:  const Icon(Icons.sync),
                  label: const Text('Sync Now'),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatLastSync(String lastSync) {
    if (lastSync.isEmpty) return 'Never';
    try {
      final date       = DateTime.parse(lastSync);
      final difference = DateTime.now().difference(date);
      if (difference.inMinutes < 1)  return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24)   return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }
}
