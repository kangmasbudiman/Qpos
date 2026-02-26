import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../services/registration/registration_service.dart';

class RegistrationListScreen extends StatefulWidget {
  const RegistrationListScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationListScreen> createState() => _RegistrationListScreenState();
}

class _RegistrationListScreenState extends State<RegistrationListScreen>
    with SingleTickerProviderStateMixin {
  final _regService = Get.find<RegistrationService>();

  late final TabController _tabCtrl;

  static const _tabs = [
    ('pending',  'Pending',    Color(0xFFFF9800)),
    ('approved', 'Disetujui',  Color(0xFF4CAF50)),
    ('rejected', 'Ditolak',    Color(0xFFF44336)),
    ('all',      'Semua',      Color(0xFF2196F3)),
  ];

  static const _dark   = Color(0xFF1E2235);
  static const _darker = Color(0xFF2D3154);

  // Per-tab state
  final Map<String, List<MerchantRegistration>> _items = {
    'pending': [], 'approved': [], 'rejected': [], 'all': [],
  };
  final Map<String, int>  _pages   = {'pending': 1, 'approved': 1, 'rejected': 1, 'all': 1};
  final Map<String, bool> _hasMore = {'pending': true, 'approved': true, 'rejected': true, 'all': true};
  final Map<String, bool> _loading = {'pending': false, 'approved': false, 'rejected': false, 'all': false};
  final Map<String, String?> _error = {'pending': null, 'approved': null, 'rejected': null, 'all': null};

  // Scroll controllers per tab
  final Map<String, ScrollController> _scrolls = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);

    // Determine initial tab from arguments
    final args       = Get.arguments as Map<String, dynamic>?;
    final initTab    = args?['initialTab'] as String? ?? 'pending';
    final tabIndex   = _tabs.indexWhere((t) => t.$1 == initTab);
    _tabCtrl.index   = tabIndex >= 0 ? tabIndex : 0;

    // Init scroll controllers and load first tab
    for (final tab in _tabs) {
      _scrolls[tab.$1] = ScrollController()
        ..addListener(() => _onScroll(tab.$1));
    }

    _loadData(_tabs[_tabCtrl.index].$1, refresh: true);

    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final key = _tabs[_tabCtrl.index].$1;
        if (_items[key]!.isEmpty) {
          _loadData(key, refresh: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final s in _scrolls.values) {
      s.dispose();
    }
    super.dispose();
  }

  void _onScroll(String key) {
    final sc = _scrolls[key]!;
    if (sc.position.pixels >= sc.position.maxScrollExtent - 150) {
      _loadMore(key);
    }
  }

  Future<void> _loadData(String key, {bool refresh = false}) async {
    if (_loading[key]! && !refresh) return;
    setState(() {
      _loading[key] = true;
      _error[key]   = null;
      if (refresh) {
        _pages[key]   = 1;
        _hasMore[key] = true;
        _items[key]!.clear();
      }
    });

    try {
      final result = await _regService.fetchRegistrations(
        status:  key,
        page:    _pages[key]!,
        perPage: 20,
      );
      final newItems = result['items'] as List<MerchantRegistration>;
      final lastPage = result['lastPage'] as int;

      setState(() {
        _items[key]!.addAll(newItems);
        _hasMore[key] = _pages[key]! < lastPage;
        _pages[key]   = _pages[key]! + 1;
      });
    } catch (e) {
      setState(() => _error[key] = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading[key] = false);
    }
  }

  Future<void> _loadMore(String key) async {
    if (!_hasMore[key]! || _loading[key]!) return;
    await _loadData(key);
  }

  Future<void> _refresh(String key) => _loadData(key, refresh: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned:          true,
            floating:        true,
            backgroundColor: _dark,
            foregroundColor: Colors.white,
            title: const Text(
              'Pendaftaran Merchant',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            bottom: TabBar(
              controller:         _tabCtrl,
              indicatorColor:     Colors.white,
              indicatorWeight:    3,
              labelColor:         Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:         const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: _tabs.map((t) => _buildTabContent(t.$1, t.$3)).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(String key, Color color) {
    final items   = _items[key]!;
    final loading = _loading[key]!;
    final hasMore = _hasMore[key]!;
    final error   = _error[key];

    if (error != null && items.isEmpty) {
      return _buildError(error, () => _loadData(key, refresh: true));
    }

    if (!loading && items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(key),
        child: ListView(children: const [
          SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 52, color: Colors.grey),
                SizedBox(height: 12),
                Text('Tidak ada data', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(key),
      child: ListView.builder(
        controller: _scrolls[key],
        padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount:  items.length + (hasMore || loading ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child:   Center(child: CircularProgressIndicator()),
            );
          }
          return _RegistrationCard(
            reg: items[i],
            onTap: () async {
              final result = await Get.toNamed('/registrations/${items[i].id}');
              if (result != null) _loadData(key, refresh: true);
            },
          );
        },
      ),
    );
  }

  Widget _buildError(String msg, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(msg,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _darker,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Registration Card ─────────────────────────────────────────────────────────

class _RegistrationCard extends StatefulWidget {
  final MerchantRegistration reg;
  final VoidCallback onTap;

  const _RegistrationCard({required this.reg, required this.onTap});

  @override
  State<_RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<_RegistrationCard> {
  final _regService = Get.find<RegistrationService>();
  bool _sending = false;

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return const Color(0xFF4CAF50);
      case 'rejected': return const Color(0xFFF44336);
      default:         return const Color(0xFFFF9800);
    }
  }

  String _fmtDate(String s) {
    try {
      return DateFormat('dd MMM yy').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return '';
    }
  }

  Future<void> _resendCode() async {
    setState(() => _sending = true);
    try {
      final emailTo = await _regService.resendCode(widget.reg.id);
      if (!mounted) return;
      Get.snackbar(
        'Terkirim',
        'Kode perusahaan dikirim ulang ke $emailTo',
        backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.9),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.TOP,
        duration:        const Duration(seconds: 4),
        icon: const Icon(Icons.mark_email_read_rounded, color: Colors.white),
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.TOP,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.reg.companyCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:  Text('Kode disalin ke clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reg        = widget.reg;
    final isApproved = reg.status == 'approved' && reg.companyCode != null;

    return Card(
      margin:      const EdgeInsets.only(bottom: 10),
      elevation:   2,
      shadowColor: Colors.black12,
      shape:       RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Baris utama ─────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _statusColor(reg.status).withValues(alpha: 0.15),
                    radius: 24,
                    child: Icon(
                      Icons.store_rounded,
                      color: _statusColor(reg.status),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reg.merchantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   14,
                            color:      Color(0xFF1A1D26),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reg.ownerName,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reg.email,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: reg.status),
                      const SizedBox(height: 6),
                      Text(
                        _fmtDate(reg.registeredAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Company code panel (hanya jika approved) ─────────────────
              if (isApproved) ...[
                const SizedBox(height: 10),
                Container(
                  padding:    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF4CAF50).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded,
                          color: Color(0xFF4CAF50), size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kode Perusahaan',
                            style: TextStyle(
                              fontSize:   10,
                              color:      Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            reg.companyCode!,
                            style: const TextStyle(
                              fontSize:      16,
                              fontWeight:    FontWeight.bold,
                              color:         Color(0xFF4CAF50),
                              letterSpacing: 3,
                              fontFamily:    'monospace',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Tombol copy
                      InkWell(
                        onTap: () => _copyCode(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Tooltip(
                            message: 'Salin kode',
                            child: Icon(Icons.copy_rounded,
                                size: 18,
                                color: Colors.grey[600]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Tombol kirim ulang email
                      _sending
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4CAF50),
                              ),
                            )
                          : InkWell(
                              onTap: () => _confirmResend(context, reg),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Tooltip(
                                  message: 'Kirim ulang ke email',
                                  child: Icon(Icons.forward_to_inbox_rounded,
                                      size: 18,
                                      color: Colors.grey[600]),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResend(BuildContext context, MerchantRegistration reg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.forward_to_inbox_rounded,
                color: Color(0xFF4CAF50), size: 22),
            SizedBox(width: 8),
            Text('Kirim Ulang Kode'),
          ],
        ),
        content: Text(
          'Kirim ulang kode perusahaan "${reg.companyCode}" ke email:\n${reg.email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _resendCode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'approved' => (const Color(0xFF4CAF50), 'Disetujui'),
      'rejected' => (const Color(0xFFF44336), 'Ditolak'),
      _          => (const Color(0xFFFF9800), 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   11,
          color:      color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
