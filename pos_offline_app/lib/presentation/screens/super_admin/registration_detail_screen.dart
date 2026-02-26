import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../services/registration/registration_service.dart';

class RegistrationDetailScreen extends StatefulWidget {
  const RegistrationDetailScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationDetailScreen> createState() =>
      _RegistrationDetailScreenState();
}

class _RegistrationDetailScreenState extends State<RegistrationDetailScreen> {
  final _regService = Get.find<RegistrationService>();

  late final int _id;

  final _reg       = Rxn<MerchantRegistration>();
  final _isLoading = true.obs;
  final _isActing  = false.obs;
  final _errorMsg  = Rxn<String>();

  static const _dark   = Color(0xFF1E2235);
  static const _darker = Color(0xFF2D3154);
  static const _accent = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _id = int.tryParse(Get.parameters['id'] ?? '') ?? 0;
    _load();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    _errorMsg.value  = null;
    try {
      _reg.value = await _regService.fetchDetail(_id);
    } catch (e) {
      _errorMsg.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Obx(() {
        final reg = _reg.value;
        return CustomScrollView(
          slivers: [
            // ── AppBar ────────────────────────────────────────────────────
            SliverAppBar(
              pinned:          true,
              backgroundColor: _dark,
              foregroundColor: Colors.white,
              expandedHeight:  reg != null ? 110 : 80,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [_dark, _darker],
                    ),
                  ),
                ),
                titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
                title: reg != null
                    ? Text(
                        reg.merchantName,
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text(
                        'Detail Pendaftaran',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _isLoading.value
                  ? const Padding(
                      padding: EdgeInsets.all(80),
                      child:   Center(child: CircularProgressIndicator()),
                    )
                  : _errorMsg.value != null
                      ? _buildError(_errorMsg.value!)
                      : reg != null
                          ? _buildContent(context, reg)
                          : const SizedBox.shrink(),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildContent(BuildContext context, MerchantRegistration reg) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          _buildStatusBanner(reg),
          const SizedBox(height: 14),

          // Info merchant
          _buildInfoCard(
            title: 'Data Usaha',
            icon:  Icons.store_rounded,
            rows: [
              ('Nama Usaha',    reg.merchantName),
              ('Jenis Usaha',   reg.businessType ?? '-'),
              ('Alamat',        reg.address ?? '-'),
              ('Email Usaha',   reg.email),
              ('No. HP',        reg.phone ?? '-'),
            ],
          ),
          const SizedBox(height: 12),

          // Info owner
          _buildInfoCard(
            title: 'Data Pemilik',
            icon:  Icons.person_outline_rounded,
            rows: [
              ('Nama Pemilik', reg.ownerName),
              ('Email',        reg.email),
            ],
          ),
          const SizedBox(height: 12),

          // Timestamps
          _buildInfoCard(
            title: 'Waktu',
            icon:  Icons.schedule_rounded,
            rows: [
              ('Tanggal Daftar', _fmtDateTime(reg.registeredAt)),
              if (reg.approvedAt != null)
                ('Tanggal Disetujui', _fmtDateTime(reg.approvedAt!)),
              if (reg.rejectedAt != null)
                ('Tanggal Ditolak', _fmtDateTime(reg.rejectedAt!)),
            ],
          ),

          // Company code jika sudah approved
          if (reg.status == 'approved' && reg.companyCode != null) ...[
            const SizedBox(height: 12),
            _buildCompanyCodeCard(reg.companyCode!),
          ],

          // Rejection reason jika ditolak
          if (reg.status == 'rejected' && reg.rejectionReason != null) ...[
            const SizedBox(height: 12),
            _buildRejectionCard(reg.rejectionReason!),
          ],

          // Action buttons (hanya jika pending)
          if (reg.status == 'pending') ...[
            const SizedBox(height: 24),
            _buildActionBar(context, reg),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MerchantRegistration reg) {
    final (color, icon, label) = switch (reg.status) {
      'approved' => (
          const Color(0xFF4CAF50),
          Icons.check_circle_rounded,
          'Pendaftaran Disetujui',
        ),
      'rejected' => (
          const Color(0xFFF44336),
          Icons.cancel_rounded,
          'Pendaftaran Ditolak',
        ),
      _ => (
          const Color(0xFFFF9800),
          Icons.pending_actions_rounded,
          'Menunggu Persetujuan',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontWeight: FontWeight.bold,
              fontSize:   15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<(String, String)> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(icon, color: _dark, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                      color:      Color(0xFF1A1D26),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((row) => _InfoRow(label: row.$1, value: row.$2)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCompanyCodeCard(String code) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kode Perusahaan',
              style: TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(code,
              style: const TextStyle(
                fontSize:      28,
                fontWeight:    FontWeight.bold,
                color:         Color(0xFF4CAF50),
                letterSpacing: 6,
              )),
          const SizedBox(height: 6),
          const Text('Kode ini diberikan kepada merchant untuk login.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRejectionCard(String reason) {
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFF44336).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
            color: const Color(0xFFF44336).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFFF44336), size: 16),
              SizedBox(width: 6),
              Text('Alasan Penolakan',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFFF44336),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(reason,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D26))),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, MerchantRegistration reg) {
    return Obx(() => Row(
      children: [
        // Tolak
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isActing.value
                ? null
                : () => _showRejectSheet(context, reg),
            icon:  const Icon(Icons.close_rounded, size: 18),
            label: const Text('Tolak',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF44336),
              side: const BorderSide(color: Color(0xFFF44336)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Setujui
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isActing.value
                ? null
                : () => _confirmApprove(context, reg),
            icon: _isActing.value
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Setujui',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    ));
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _confirmApprove(BuildContext context, MerchantRegistration reg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Setujui Pendaftaran'),
        content: Text(
          'Anda akan menyetujui pendaftaran "${reg.merchantName}".\n\n'
          'Kode perusahaan akan dibuat otomatis dan merchant dapat segera login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _handleApprove(reg);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(MerchantRegistration reg) async {
    _isActing.value = true;
    try {
      final result = await _regService.approve(reg.id);
      final code   = result['company_code'] as String? ?? '';

      // Tampilkan dialog sukses dengan company code yang prominent
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color:        const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    shape:        BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pendaftaran Disetujui!',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reg.merchantName,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width:      double.infinity,
                  padding:    const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF4CAF50).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KODE PERUSAHAAN',
                        style: TextStyle(
                          fontSize:      11,
                          color:         Colors.grey,
                          fontWeight:    FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize:      32,
                          fontWeight:    FontWeight.bold,
                          color:         Color(0xFF4CAF50),
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Berikan kode ini kepada merchant untuk login',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding:         const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Get.back(result: 'approved');
    } catch (e) {
      // Dialog error
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Gagal Menyetujui'),
            ],
          ),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } finally {
      _isActing.value = false;
    }
  }

  void _showRejectSheet(BuildContext context, MerchantRegistration reg) {
    final reasonCtrl = TextEditingController();
    final formKey    = GlobalKey<FormState>();

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left:   20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Alasan Penolakan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Tolak pendaftaran "${reg.merchantName}"',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonCtrl,
                maxLines:   4,
                decoration: InputDecoration(
                  hintText:  'Tuliskan alasan penolakan...',
                  border:    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled:    true,
                  fillColor: Colors.grey[50],
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Alasan penolakan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Get.back();
                        await _handleReject(reg, reasonCtrl.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Tolak Pendaftaran',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      ignoreSafeArea:      false,
    );
  }

  Future<void> _handleReject(MerchantRegistration reg, String reason) async {
    _isActing.value = true;
    try {
      await _regService.reject(reg.id, reason);

      // Dialog sukses penolakan
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF44336).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFF44336),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pendaftaran Ditolak',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reg.merchantName,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width:      double.infinity,
                  padding:    const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF44336).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(
                        color: const Color(0xFFF44336).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alasan Penolakan',
                        style: TextStyle(
                          fontSize:   11,
                          color:      Color(0xFFF44336),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 13,
                          color:    Color(0xFF1A1D26),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF44336),
                      foregroundColor: Colors.white,
                      padding:         const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Get.back(result: 'rejected');
    } catch (e) {
      // Dialog error
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Gagal Menolak'),
            ],
          ),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } finally {
      _isActing.value = false;
    }
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.all(40),
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

  String _fmtDateTime(String s) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return s;
    }
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          const Text(': ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1A1D26),
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}
