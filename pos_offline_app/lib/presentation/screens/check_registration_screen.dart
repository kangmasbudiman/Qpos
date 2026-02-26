import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/auth/auth_service.dart';
import '../../core/utils/connectivity_utils.dart';

class CheckRegistrationScreen extends StatefulWidget {
  const CheckRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<CheckRegistrationScreen> createState() => _CheckRegistrationScreenState();
}

class _CheckRegistrationScreenState extends State<CheckRegistrationScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _authService = Get.find<AuthService>();
  final _emailCtrl   = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _result;

  static const _accent   = Color(0xFFFF6B35);
  static const _darkText = Color(0xFF2D3142);

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;

    if (!await ConnectivityUtils.hasInternetConnection()) {
      Get.snackbar(
        'Tidak Ada Koneksi',
        'Pengecekan status membutuhkan koneksi internet.',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.TOP,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result    = null;
    });

    try {
      final data = await _authService.checkRegistrationStatus(
          _emailCtrl.text.trim());
      setState(() => _result = data);
    } catch (e) {
      Get.snackbar(
        'Tidak Ditemukan',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.TOP,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation:       0,
        title: const Text(
          'Cek Status Pendaftaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? size.width * 0.2 : 20,
            vertical:   24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ilustrasi
              Container(
                padding:    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color:  _accent.withValues(alpha: 0.12),
                        shape:  BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_rounded,
                          color: _accent, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cek Status Pendaftaran',
                      style: TextStyle(
                        fontSize:   17,
                        fontWeight: FontWeight.bold,
                        color:      _darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan email yang Anda gunakan saat mendaftar\nuntuk mengecek status persetujuan.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form email
              Container(
                padding:    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller:   _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Email Pendaftaran',
                          hintText:  'Masukkan email Anda',
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: _accent, size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _accent, width: 2),
                          ),
                          filled:    true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!GetUtils.isEmail(v.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _check,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation:       3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Cek Status',
                                  style: TextStyle(
                                      fontSize:   15,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Hasil
              if (_result != null) ...[
                const SizedBox(height: 20),
                _buildResultCard(_result!),
              ],

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Get.offAllNamed('/login'),
                  child: const Text('Kembali ke Login',
                      style: TextStyle(color: _accent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final status       = data['registration_status'] as String? ?? '';
    final merchantName = data['merchant_name'] as String? ?? '-';
    final message      = data['message'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon  = Icons.check_circle_rounded;
        statusLabel = 'Disetujui';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon  = Icons.cancel_rounded;
        statusLabel = 'Ditolak';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon  = Icons.hourglass_top_rounded;
        statusLabel = 'Menunggu';
    }

    return Container(
      padding:    const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: statusColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: $statusLabel',
                    style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      color:      statusColor,
                    ),
                  ),
                  Text(
                    merchantName,
                    style: const TextStyle(
                        fontSize: 13, color: _darkText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),

          // Company code jika sudah approved
          if (status == 'approved' && data['company_code'] != null) ...[
            const SizedBox(height: 14),
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                    color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kode Perusahaan Anda:',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['company_code'] as String,
                    style: const TextStyle(
                      fontSize:      24,
                      fontWeight:    FontWeight.bold,
                      color:         Colors.green,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gunakan kode ini untuk login ke aplikasi POS.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width:  double.infinity,
              height: 46,
              child:  ElevatedButton.icon(
                onPressed: () => Get.offAllNamed('/login'),
                icon:  const Icon(Icons.login_rounded, size: 18),
                label: const Text('Login Sekarang',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

          // Rejection reason jika ditolak
          if (status == 'rejected' &&
              data['rejection_reason'] != null) ...[
            const SizedBox(height: 14),
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                    color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alasan Penolakan:',
                    style: TextStyle(
                        fontSize: 12, color: Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['rejection_reason'] as String,
                    style: const TextStyle(
                        fontSize: 13, color: _darkText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width:  double.infinity,
              height: 46,
              child:  OutlinedButton.icon(
                onPressed: () => Get.toNamed('/register'),
                icon:  const Icon(Icons.refresh_rounded,
                    size: 18, color: _accent),
                label: const Text('Daftar Ulang',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _accent)),
                style: OutlinedButton.styleFrom(
                  side:  const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
