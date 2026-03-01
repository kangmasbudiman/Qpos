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

  final _stats        = Rxn<RegistrationStats>();
  final _recent       = <MerchantRegistration>[].obs;
  final _merchants    = <MerchantSubInfo>[].obs;
  final _isLoading    = true.obs;
  final _subLoading   = false.obs;
  final _errorMsg     = Rxn<String>();

  // Filter subscription list
  final _subFilter    = 'all'.obs; // all | trial | active | expired | suspended

  // Pricing settings
  final _priceMonthlyCtrl    = TextEditingController();
  final _priceYearlyCtrl     = TextEditingController();
  final _trialDaysCtrl       = TextEditingController();
  final _supportEmailCtrl    = TextEditingController();
  final _supportWaCtrl       = TextEditingController();
  final _settingsSaving      = false.obs;
  final _settingsLoaded      = false.obs;

  static const _dark   = Color(0xFF1E2235);
  static const _darker = Color(0xFF2D3154);
  static const _accent = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceMonthlyCtrl.dispose();
    _priceYearlyCtrl.dispose();
    _trialDaysCtrl.dispose();
    _supportEmailCtrl.dispose();
    _supportWaCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    _errorMsg.value  = null;
    try {
      final results = await Future.wait([
        _regService.fetchStats(),
        _regService.fetchRegistrations(status: 'pending', perPage: 5),
        _regService.fetchMerchantSubscriptions(),
        _regService.fetchSettings(),
      ]);
      _stats.value = results[0] as RegistrationStats;
      _recent.assignAll(
          (results[1] as Map<String, dynamic>)['items'] as List<MerchantRegistration>);
      _merchants.assignAll(results[2] as List<MerchantSubInfo>);
      _applySettings(results[3] as Map<String, String>);
    } catch (e) {
      _errorMsg.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _refreshSubscriptions() async {
    _subLoading.value = true;
    try {
      final list = await _regService.fetchMerchantSubscriptions();
      _merchants.assignAll(list);
    } catch (_) {} finally {
      _subLoading.value = false;
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
                    _buildPricingSettings(),
                    const SizedBox(height: 14),
                    _buildMerchantSubscriptions(),
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

  // ── Pricing Settings ─────────────────────────────────────────────────────

  void _applySettings(Map<String, String> s) {
    _priceMonthlyCtrl.text = s['price_monthly'] ?? '99000';
    _priceYearlyCtrl.text  = s['price_yearly']  ?? '990000';
    _trialDaysCtrl.text    = s['trial_days']    ?? '7';
    _supportEmailCtrl.text = s['support_email'] ?? 'support@payzen.id';
    _supportWaCtrl.text    = s['support_whatsapp'] ?? '';
    _settingsLoaded.value  = true;
  }

  Future<void> _saveSettings() async {
    _settingsSaving.value = true;
    try {
      await _regService.saveSettings({
        'price_monthly':    int.tryParse(_priceMonthlyCtrl.text.replaceAll('.', '')) ?? 99000,
        'price_yearly':     int.tryParse(_priceYearlyCtrl.text.replaceAll('.', '')) ?? 990000,
        'trial_days':       int.tryParse(_trialDaysCtrl.text) ?? 7,
        'support_email':    _supportEmailCtrl.text.trim(),
        'support_whatsapp': _supportWaCtrl.text.trim(),
      });
      Get.snackbar('Berhasil', 'Pengaturan berhasil disimpan',
          backgroundColor: Colors.green[600],
          colorText: Colors.white,
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Gagal', e.toString().replaceAll('Exception: ', ''),
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      _settingsSaving.value = false;
    }
  }

  Widget _buildPricingSettings() {
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
      child: Obx(() {
        if (!_settingsLoaded.value) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF1E2235)),
                  const SizedBox(width: 8),
                  const Text(
                    'Pengaturan Harga & Langganan',
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                      color:      Color(0xFF1A1D26),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Harga bulanan & tahunan (berdampingan)
                  Row(
                    children: [
                      Expanded(child: _PriceField(
                        ctrl:  _priceMonthlyCtrl,
                        label: 'Harga Bulanan',
                        hint:  '99000',
                        icon:  Icons.calendar_month_rounded,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _PriceField(
                        ctrl:  _priceYearlyCtrl,
                        label: 'Harga Tahunan',
                        hint:  '990000',
                        icon:  Icons.workspace_premium_rounded,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Trial days
                  _SettingField(
                    ctrl:        _trialDaysCtrl,
                    label:       'Durasi Trial (hari)',
                    hint:        '7',
                    icon:        Icons.timelapse_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Support email
                  _SettingField(
                    ctrl:        _supportEmailCtrl,
                    label:       'Email Support',
                    hint:        'support@payzen.id',
                    icon:        Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  // WhatsApp
                  _SettingField(
                    ctrl:        _supportWaCtrl,
                    label:       'WhatsApp Support (opsional)',
                    hint:        '628xxxxxxxxx',
                    icon:        Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  // Simpan button
                  SizedBox(
                    width: double.infinity,
                    child: Obx(() => ElevatedButton.icon(
                      onPressed: _settingsSaving.value ? null : _saveSettings,
                      icon: _settingsSaving.value
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_settingsSaving.value ? 'Menyimpan...' : 'Simpan Pengaturan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2235),
                        foregroundColor: Colors.white,
                        padding:         const EdgeInsets.symmetric(vertical: 13),
                        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation:       0,
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Merchant Subscription List ────────────────────────────────────────────

  Widget _buildMerchantSubscriptions() {
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    size: 18, color: Color(0xFF1E2235)),
                const SizedBox(width: 8),
                const Text(
                  'Status Langganan Merchant',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFF1A1D26),
                  ),
                ),
                const Spacer(),
                Obx(() => _subLoading.value
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon:     const Icon(Icons.refresh_rounded, size: 18),
                        tooltip:  'Refresh',
                        onPressed: _refreshSubscriptions,
                        padding:  EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )),
              ],
            ),
          ),

          // Filter chips
          Obx(() {
            final filters = [
              ('all', 'Semua'),
              ('trial', 'Trial'),
              ('active', 'Aktif'),
              ('expired', 'Kadaluarsa'),
              ('suspended', 'Ditangguhkan'),
            ];
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: filters.map((f) {
                  final selected = _subFilter.value == f.$1;
                  final color = _subStatusColor(f.$1 == 'all' ? 'active' : f.$1);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _subFilter.value = f.$1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color:        selected ? color : color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border:       Border.all(
                            color: selected ? color : color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          f.$2,
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      selected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),

          const Divider(height: 1),

          // List
          Obx(() {
            final filter = _subFilter.value;
            final list = filter == 'all'
                ? _merchants
                : _merchants.where((m) => m.subStatus == filter).toList();

            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text('Tidak ada merchant',
                      style: TextStyle(color: Colors.grey)),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap:       true,
              physics:          const NeverScrollableScrollPhysics(),
              itemCount:        list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder:      (_, i) => _buildSubTile(list[i]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubTile(MerchantSubInfo m) {
    final statusColor = _subStatusColor(m.subStatus);
    final statusLabel = _subStatusLabel(m.subStatus);
    final expiryText  = _subExpiryText(m);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: statusColor.withValues(alpha: 0.12),
        child: Text(
          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
          style: TextStyle(
            color:      statusColor,
            fontWeight: FontWeight.bold,
            fontSize:   15,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              m.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color:        statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w700,
                color:      statusColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.companyCode,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 11, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text(
                expiryText,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (m.subStatus == 'trial' || m.subStatus == 'active') ...[
                const SizedBox(width: 6),
                Text(
                  '· ${m.daysRemaining}h lagi',
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      m.daysRemaining <= 3
                        ? Colors.red
                        : Colors.green[600],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon:    const Icon(Icons.more_vert_rounded, size: 18),
        tooltip: 'Kelola',
        onPressed: () => _showSubActions(m),
      ),
    );
  }

  void _showSubActions(MerchantSubInfo m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color:        Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Merchant name
            Text(m.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(m.email,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 4),
            _SubStatusRow(status: m.subStatus, expiryText: _subExpiryText(m),
                daysRemaining: m.daysRemaining),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Action buttons — harga dari setting
            Builder(builder: (_) {
              final pricing = Get.find<AuthService>().pricing;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.subStatus != 'active') ...[
                    _SubActionTile(
                      icon:  Icons.check_circle_rounded,
                      color: Colors.green,
                      label: 'Aktifkan Bulanan (${pricing.formattedMonthly})',
                      onTap: () async {
                        Get.back();
                        await _doSubscriptionAction(() => _regService.activateSubscription(
                            m.id, 'monthly', pricing.priceMonthly.toDouble()));
                      },
                    ),
                    _SubActionTile(
                      icon:  Icons.workspace_premium_rounded,
                      color: Colors.indigo,
                      label: 'Aktifkan Tahunan (${pricing.formattedYearly})',
                      onTap: () async {
                        Get.back();
                        await _doSubscriptionAction(() => _regService.activateSubscription(
                            m.id, 'yearly', pricing.priceYearly.toDouble()));
                      },
                    ),
                  ],
                  if (m.subStatus == 'active') ...[
                    _SubActionTile(
                      icon:  Icons.autorenew_rounded,
                      color: Colors.blue,
                      label: 'Perpanjang Bulanan (${pricing.formattedMonthly})',
                      onTap: () async {
                        Get.back();
                        await _doSubscriptionAction(() => _regService.extendSubscription(
                            m.id, 'monthly', pricing.priceMonthly.toDouble()));
                      },
                    ),
                    _SubActionTile(
                      icon:  Icons.star_rounded,
                      color: Colors.indigo,
                      label: 'Perpanjang Tahunan (${pricing.formattedYearly})',
                      onTap: () async {
                        Get.back();
                        await _doSubscriptionAction(() => _regService.extendSubscription(
                            m.id, 'yearly', pricing.priceYearly.toDouble()));
                      },
                    ),
                  ],
                ],
              );
            }),
            _SubActionTile(
              icon:  Icons.replay_rounded,
              color: Colors.orange,
              label: 'Reset Trial 7 Hari',
              onTap: () async {
                Get.back();
                await _doSubscriptionAction(() => _regService.resetTrial(m.id));
              },
            ),
            if (m.subStatus != 'suspended')
              _SubActionTile(
                icon:  Icons.block_rounded,
                color: Colors.red,
                label: 'Suspend Akun',
                onTap: () async {
                  Get.back();
                  await _doSubscriptionAction(() => _regService.suspendMerchant(m.id));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doSubscriptionAction(Future<void> Function() action) async {
    try {
      await action();
      await _refreshSubscriptions();
      Get.snackbar('Berhasil', 'Status langganan diperbarui',
          backgroundColor: Colors.green[600],
          colorText: Colors.white,
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Gagal', e.toString().replaceAll('Exception: ', ''),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3));
    }
  }

  static Color _subStatusColor(String status) {
    switch (status) {
      case 'trial':     return Colors.orange;
      case 'active':    return Colors.green;
      case 'suspended': return Colors.red;
      default:          return Colors.grey;
    }
  }

  static String _subStatusLabel(String status) {
    switch (status) {
      case 'trial':     return 'TRIAL';
      case 'active':    return 'AKTIF';
      case 'expired':   return 'KADALUARSA';
      case 'suspended': return 'SUSPEND';
      default:          return status.toUpperCase();
    }
  }

  String _subExpiryText(MerchantSubInfo m) {
    if (m.subStatus == 'trial' && m.trialEndsAt != null) {
      return 'Trial hingga ${_fmtDate(m.trialEndsAt!)}';
    }
    if (m.subStatus == 'active' && m.subEndsAt != null) {
      final plan = m.planType == 'yearly' ? 'Tahunan' : 'Bulanan';
      return '$plan · hingga ${_fmtDate(m.subEndsAt!)}';
    }
    if (m.subStatus == 'expired') return 'Langganan berakhir';
    if (m.subStatus == 'suspended') return 'Akun ditangguhkan';
    return '-';
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

// ── Pricing Field Widgets ──────────────────────────────────────────────────

class _PriceField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;

  const _PriceField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller:   ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixText:  'Rp ',
            hintText:    hint,
            isDense:     true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: Color(0xFF1E2235), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _SettingField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText:   label,
        hintText:    hint,
        prefixIcon:  Icon(icon, size: 18, color: Colors.grey[500]),
        isDense:     true,
        border:      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: Color(0xFF1E2235), width: 1.5),
        ),
      ),
    );
  }
}

// ── Subscription Helper Widgets ───────────────────────────────────────────

class _SubStatusRow extends StatelessWidget {
  final String status;
  final String expiryText;
  final int    daysRemaining;

  const _SubStatusRow({
    required this.status,
    required this.expiryText,
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'trial':     color = Colors.orange;  break;
      case 'active':    color = Colors.green;   break;
      case 'suspended': color = Colors.red;     break;
      default:          color = Colors.grey;
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border:       Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            expiryText,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        if (status == 'trial' || status == 'active')
          Text(
            '$daysRemaining hari',
            style: TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color:      daysRemaining <= 3 ? Colors.red : Colors.green[600],
            ),
          ),
      ],
    );
  }
}

class _SubActionTile extends StatelessWidget {
  final IconData    icon;
  final Color       color;
  final String      label;
  final VoidCallback onTap;

  const _SubActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding:    const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

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
