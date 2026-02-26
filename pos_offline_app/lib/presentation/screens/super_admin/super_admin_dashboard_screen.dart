import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../services/registration/registration_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../controllers/auth_controller.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final _regService  = Get.find<RegistrationService>();
  final _authService = Get.find<AuthService>();

  final _stats       = Rxn<RegistrationStats>();
  final _recent      = <MerchantRegistration>[].obs;
  final _isLoading   = true.obs;
  final _errorMsg    = Rxn<String>();

  static const _dark   = Color(0xFF1E2235);
  static const _darker = Color(0xFF2D3154);
  static const _accent = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    _errorMsg.value  = null;
    try {
      final results = await Future.wait([
        _regService.fetchStats(),
        _regService.fetchRegistrations(status: 'pending', perPage: 5),
      ]);
      _stats.value = results[0] as RegistrationStats;
      _recent.assignAll(
          (results[1] as Map<String, dynamic>)['items'] as List<MerchantRegistration>);
    } catch (e) {
      _errorMsg.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight:          120,
            pinned:                  true,
            automaticallyImplyLeading: false,
            backgroundColor:         _dark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                    colors: [_dark, _darker],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding:    const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:        _accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment:  MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Super Admin Panel',
                                style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user?.name ?? '',
                                style: TextStyle(
                                  color:    Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon:    const Icon(Icons.refresh_rounded, color: Colors.white),
                          onPressed: _load,
                          tooltip: 'Refresh',
                        ),
                        IconButton(
                          icon:    const Icon(Icons.logout_rounded, color: Colors.white),
                          onPressed: () => _confirmLogout(context),
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Obx(() {
              if (_isLoading.value) {
                return const Padding(
                  padding: EdgeInsets.all(80),
                  child:   Center(child: CircularProgressIndicator()),
                );
              }
              if (_errorMsg.value != null) {
                return _buildError(_errorMsg.value!);
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 14),
                    _buildQuickActions(),
                    const SizedBox(height: 14),
                    _buildRecentPending(),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final s = _stats.value;
    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Total',
          value: '${s?.total ?? 0}',
          color: const Color(0xFF2196F3),
          icon:  Icons.store_rounded,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          label: 'Pending',
          value: '${s?.pending ?? 0}',
          color: const Color(0xFFFF9800),
          icon:  Icons.pending_actions_rounded,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          label: 'Disetujui',
          value: '${s?.approved ?? 0}',
          color: const Color(0xFF4CAF50),
          icon:  Icons.check_circle_rounded,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          label: 'Ditolak',
          value: '${s?.rejected ?? 0}',
          color: const Color(0xFFF44336),
          icon:  Icons.cancel_rounded,
        )),
      ],
    );
  }

  // ── Quick Action Buttons ─────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon:  Icons.pending_actions_rounded,
            label: 'Lihat Pending',
            color: const Color(0xFFFF9800),
            onTap: () => Get.toNamed('/registrations',
                arguments: {'initialTab': 'pending'}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBtn(
            icon:  Icons.list_alt_rounded,
            label: 'Semua Daftar',
            color: const Color(0xFF2196F3),
            onTap: () => Get.toNamed('/registrations',
                arguments: {'initialTab': 'all'}),
          ),
        ),
      ],
    );
  }

  // ── Recent Pending ───────────────────────────────────────────────────────

  Widget _buildRecentPending() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Pending Terbaru',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFF1A1D26),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Get.toNamed('/registrations',
                      arguments: {'initialTab': 'pending'}),
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontSize:   12,
                      color:      _accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Obx(() => _recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded, size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Tidak ada pendaftaran pending',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap:     true,
                  physics:        const NeverScrollableScrollPhysics(),
                  itemCount:      _recent.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder:    (_, i) => _buildTile(_recent[i]),
                )),
        ],
      ),
    );
  }

  Widget _buildTile(MerchantRegistration reg) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFF9800).withValues(alpha: 0.15),
        child: const Icon(Icons.store_rounded,
            color: Color(0xFFFF9800), size: 20),
      ),
      title: Text(
        reg.merchantName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${reg.ownerName} · ${reg.email}',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _fmtDate(reg.registeredAt),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      onTap: () async {
        final result = await Get.toNamed('/registrations/${reg.id}');
        if (result != null) _load();
      },
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon:  const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Keluar dari Super Admin Panel?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.find<AuthController>().handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String s) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return '';
    }
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.w600,
                  fontSize:   13,
                )),
          ],
        ),
      ),
    );
  }
}
