import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';
import '../../services/sync/auto_sync_service.dart';
import '../../services/sync/sync_service.dart';
import '../../services/sync/sync_settings_service.dart';
import '../../services/database/database_helper.dart';

// Warna tema utama (sama dengan dashboard)
const _kPrimary  = Color(0xFF1E2235);
const _kAccent   = Color(0xFFFF6B35);
const _kGreen    = Color(0xFF4CAF50);
const _kBlue     = Color(0xFF2196F3);
const _kPurple   = Color(0xFF9C27B0);

class SyncDebugScreen extends StatelessWidget {
  const SyncDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync         = Get.find<SyncService>();
    final autoSync     = Get.find<AutoSyncService>();
    final syncSettings = Get.find<SyncSettingsService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroBackground(sync: sync),
            ),
            title: const Text(
              'Sinkronisasi',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Kartu Status ─────────────────────────────────
                _SectionTitle(
                    icon: Icons.info_outline_rounded, label: 'Status'),
                const SizedBox(height: 10),
                _StatusCard(
                    sync: sync,
                    autoSync: autoSync,
                    syncSettings: syncSettings),

                const SizedBox(height: 20),

                // ── Pengaturan Auto Sync ──────────────────────────
                _SectionTitle(
                    icon: Icons.tune_rounded, label: 'Pengaturan Auto Sync'),
                const SizedBox(height: 10),
                _AutoSyncCard(autoSync: autoSync, syncSettings: syncSettings),

                const SizedBox(height: 20),

                // ── Manual Sync ───────────────────────────────────
                _SectionTitle(
                    icon: Icons.cloud_upload_rounded,
                    label: 'Sinkron Manual'),
                const SizedBox(height: 10),
                _ManualSyncCard(sync: sync, autoSync: autoSync),

                const SizedBox(height: 20),

                // ── Antrian ───────────────────────────────────────
                _SectionTitle(
                    icon: Icons.pending_actions_rounded,
                    label: 'Antrian Pending'),
                const SizedBox(height: 10),
                _QueueCard(sync: sync),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Background
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.sync});
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
          child: Row(
            children: [
              // Ikon besar dekoratif
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _kAccent.withValues(alpha: 0.4), width: 1.5),
                ),
                child:
                    const Icon(Icons.sync_rounded, color: _kAccent, size: 30),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Data Sinkronisasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Obx(() => Text(
                          sync.pendingCount > 0
                              ? '${sync.pendingCount} item menunggu dikirim ke server'
                              : 'Semua data sudah tersinkron ✓',
                          style: TextStyle(
                            color: sync.pendingCount > 0
                                ? Colors.orange.shade300
                                : Colors.green.shade300,
                            fontSize: 13,
                          ),
                        )),
                  ],
                ),
              ),

              // Badge pending count
              Obx(() {
                final count = sync.pendingCount;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _kPrimary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _kPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Card
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.sync,
    required this.autoSync,
    required this.syncSettings,
  });
  final SyncService         sync;
  final AutoSyncService     autoSync;
  final SyncSettingsService syncSettings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          // Row stats
          Obx(() {
            final pending = sync.pendingCount;
            final ok      = autoSync.autoSyncSuccessCountRx.value;
            final fail    = autoSync.autoSyncFailureCountRx.value;
            return Row(
              children: [
                _StatBox(
                  label: 'Pending',
                  value: '$pending',
                  color: pending > 0 ? _kAccent : _kGreen,
                  icon:  Icons.pending_rounded,
                ),
                const SizedBox(width: 12),
                _StatBox(
                  label: 'Berhasil',
                  value: '$ok',
                  color: _kGreen,
                  icon:  Icons.check_circle_outline,
                ),
                const SizedBox(width: 12),
                _StatBox(
                  label: 'Gagal',
                  value: '$fail',
                  color: fail > 0 ? Colors.red : Colors.grey,
                  icon:  Icons.error_outline,
                ),
              ],
            );
          }),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Info rows
          Obx(() {
            final last = sync.lastSyncTime;
            String lastLabel = 'Belum pernah';
            if (last.isNotEmpty) {
              try {
                final dt = DateTime.parse(last).toLocal();
                lastLabel =
                    DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
              } catch (_) {
                lastLabel = last;
              }
            }
            return Column(
              children: [
                _InfoRow(
                  icon:  Icons.access_time_rounded,
                  label: 'Terakhir sync',
                  value: lastLabel,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon:  Icons.dns_rounded,
                  label: 'Server',
                  value: AppConstants.baseUrl
                      .replaceFirst('http://', '')
                      .replaceFirst('https://', ''),
                ),
                const SizedBox(height: 10),
                Obx(() => _InfoRow(
                      icon: autoSync.isAutoSyncEnabledRx.value
                          ? Icons.autorenew_rounded
                          : Icons.sync_disabled_rounded,
                      label: 'Auto sync',
                      value: autoSync.isAutoSyncEnabledRx.value
                          ? 'Aktif (${syncSettings.intervalLabel})'
                          : 'Nonaktif',
                      valueColor: autoSync.isAutoSyncEnabledRx.value
                          ? _kGreen
                          : Colors.grey,
                    )),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto Sync Card
// ─────────────────────────────────────────────────────────────────────────────

class _AutoSyncCard extends StatelessWidget {
  const _AutoSyncCard({required this.autoSync, required this.syncSettings});
  final AutoSyncService     autoSync;
  final SyncSettingsService syncSettings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle aktif / nonaktif ────────────────────────────
          Obx(() {
            final enabled = autoSync.isAutoSyncEnabledRx.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                        colors: [Color(0xFF1E2235), Color(0xFF2D3154)])
                    : null,
                color: enabled ? null : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  enabled ? 'Auto Sync Aktif' : 'Auto Sync Nonaktif',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: enabled ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                subtitle: Obx(() => Text(
                      enabled
                          ? 'Sinkron otomatis setiap ${syncSettings.intervalLabel}'
                          : 'Aktifkan untuk sinkron otomatis',
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.grey,
                      ),
                    )),
                value:              enabled,
                activeColor:        _kAccent,
                inactiveThumbColor: Colors.grey,
                onChanged:          autoSync.setAutoSyncEnabled,
              ),
            );
          }),

          const SizedBox(height: 20),

          // ── Pemilih interval ───────────────────────────────────
          Row(
            children: [
              const Icon(Icons.schedule_send_rounded,
                  size: 16, color: _kPrimary),
              const SizedBox(width: 8),
              const Text(
                'Interval Sinkronisasi',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _kPrimary),
              ),
              const Spacer(),
              Obx(() => Text(
                    syncSettings.intervalLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _kAccent),
                  )),
            ],
          ),
          const SizedBox(height: 12),

          // Chip-chip pilihan interval
          Obx(() {
            final current = syncSettings.intervalMinutes.value;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.syncIntervalOptions.map((min) {
                final selected = current == min;
                return GestureDetector(
                  onTap: () => autoSync.changeInterval(min),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _kAccent : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? _kAccent
                            : Colors.grey.shade300,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _kAccent.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      SyncSettingsService.labelFor(min),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: selected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Info chips: retry & batch ──────────────────────────
          Row(
            children: [
              _InfoChip(
                icon:  Icons.replay_rounded,
                label: 'Max retry',
                value: '${AppConstants.maxRetryAttempts}x',
                color: _kAccent,
              ),
              const SizedBox(width: 10),
              _InfoChip(
                icon:  Icons.batch_prediction_rounded,
                label: 'Batch',
                value: '${AppConstants.batchSyncSize} item',
                color: _kPurple,
              ),
            ],
          ),

          // ── Sync berikutnya ────────────────────────────────────
          Obx(() {
            if (!autoSync.isAutoSyncEnabledRx.value) {
              return const SizedBox.shrink();
            }
            final next = autoSync.getNextSyncTime().toLocal();
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Icon(Icons.update_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Sync berikutnya: ${DateFormat('HH:mm:ss').format(next)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manual Sync Card
// ─────────────────────────────────────────────────────────────────────────────

class _ManualSyncCard extends StatelessWidget {
  const _ManualSyncCard({required this.sync, required this.autoSync});
  final SyncService     sync;
  final AutoSyncService autoSync;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kirim semua data yang belum tersinkron ke server sekarang juga.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),

          Obx(() {
            final isSyncing = sync.isSyncing;
            final pending   = sync.pendingCount;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: isSyncing || pending == 0
                    ? null
                    : const LinearGradient(
                        colors: [_kAccent, Color(0xFFFF8C42)],
                      ),
                color: isSyncing || pending == 0
                    ? Colors.grey.shade200
                    : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSyncing || pending == 0
                    ? null
                    : [
                        BoxShadow(
                          color: _kAccent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        )
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: isSyncing
                      ? null
                      : () async {
                          if (pending == 0) {
                            Get.snackbar(
                              'Sudah tersinkron',
                              'Tidak ada data yang perlu dikirim',
                              snackPosition:   SnackPosition.BOTTOM,
                              backgroundColor: _kGreen,
                              colorText:       Colors.white,
                              margin:          const EdgeInsets.all(12),
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.white),
                            );
                            return;
                          }
                          await autoSync.forceSync();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSyncing)
                          const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.grey, strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.cloud_upload_rounded,
                            color: pending > 0
                                ? Colors.white
                                : Colors.grey,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          isSyncing
                              ? 'Sedang sinkron...'
                              : pending > 0
                                  ? 'Sinkron Sekarang  ($pending item)'
                                  : 'Semua sudah tersinkron',
                          style: TextStyle(
                            color: pending > 0 && !isSyncing
                                ? Colors.white
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue Card
// ─────────────────────────────────────────────────────────────────────────────

class _QueueCard extends StatefulWidget {
  const _QueueCard({required this.sync});
  final SyncService sync;

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _queue   = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Reload tiap kali pendingCount berubah
    ever(widget.sync.pendingCountRx, (_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final q = await _db.query(DatabaseTables.syncQueue,
        orderBy: 'created_at ASC');
    if (mounted) setState(() { _queue = q; _loading = false; });
  }

  Color _opColor(String op) {
    switch (op) {
      case 'create': return _kGreen;
      case 'update': return _kBlue;
      case 'delete': return Colors.red;
      default:       return Colors.grey;
    }
  }

  String _opLabel(String op) {
    switch (op) {
      case 'create': return 'TAMBAH';
      case 'update': return 'EDIT';
      case 'delete': return 'HAPUS';
      default:       return op.toUpperCase();
    }
  }

  String _tableLabel(String t) {
    const m = {
      'categories': 'Kategori',
      'products':   'Produk',
      'customers':  'Pelanggan',
      'sales':      'Penjualan',
    };
    return m[t] ?? t;
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          : _queue.isEmpty
              ? _EmptyQueue()
              : Column(
                  children: [
                    // Header jumlah
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_queue.length} item',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh'),
                          onPressed: _load,
                        ),
                        if (_queue.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.delete_sweep_rounded,
                                size: 16, color: Colors.red),
                            label: const Text('Bersihkan',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Bersihkan Queue?'),
                                  content: const Text(
                                      'Semua item pending akan dihapus dari antrian sinkronisasi.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Batal')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Hapus',
                                            style: TextStyle(
                                                color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _db.delete(DatabaseTables.syncQueue);
                                await _load();
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(_queue.length, (i) {
                      final item  = _queue[i];
                      final table = item['table_name'] as String? ?? '';
                      final op    = item['operation']  as String? ?? '';
                      final retry = item['retry_count'] as int? ?? 0;
                      final color = _opColor(op);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            // Icon operasi
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                op == 'create'
                                    ? Icons.add_circle_outline
                                    : op == 'update'
                                        ? Icons.edit_outlined
                                        : Icons.delete_outline,
                                color: color, size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(
                                      _tableLabel(table),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _opLabel(op),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ]),
                                  if (retry > 0)
                                    Text(
                                      'Retry $retry/${AppConstants.maxRetryAttempts}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700),
                                    ),
                                ],
                              ),
                            ),

                            // Status dot
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: _kGreen, size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'Semua data sudah tersinkron',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada antrian yang menunggu',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String   label, value;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String   label, value;
  final Color?   valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
        ),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            )),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String   label, value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}
