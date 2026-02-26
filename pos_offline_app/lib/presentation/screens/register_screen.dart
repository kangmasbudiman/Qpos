import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/auth/auth_service.dart';
import '../../core/utils/connectivity_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _authService    = Get.find<AuthService>();

  // Controllers
  final _nameCtrl         = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _phoneCtrl        = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  final _confirmPwCtrl    = TextEditingController();
  final _merchantNameCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _addressCtrl      = TextEditingController();

  bool _obscurePw      = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  static const _accent     = Color(0xFFFF6B35);
  static const _darkText   = Color(0xFF2D3142);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwCtrl.dispose();
    _merchantNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!await ConnectivityUtils.hasInternetConnection()) {
      Get.snackbar(
        'Tidak Ada Koneksi',
        'Pendaftaran membutuhkan koneksi internet.',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.TOP,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerMerchant(
        name:                 _nameCtrl.text.trim(),
        email:                _emailCtrl.text.trim(),
        password:             _passwordCtrl.text,
        passwordConfirmation: _confirmPwCtrl.text,
        merchantName:         _merchantNameCtrl.text.trim(),
        phone:                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        businessType:         _businessTypeCtrl.text.trim().isEmpty ? null : _businessTypeCtrl.text.trim(),
        address:              _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );

      // Pendaftaran berhasil → tunjukkan dialog sukses
      _showSuccessDialog();
    } catch (e) {
      Get.snackbar(
        'Pendaftaran Gagal',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText:       Colors.white,
        snackPosition:   SnackPosition.TOP,
        duration:        const Duration(seconds: 4),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context:    context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:  _accent.withValues(alpha: 0.12),
                shape:  BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: _accent, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pendaftaran Berhasil!',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      _darkText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Pendaftaran Anda sedang ditinjau oleh admin.\n'
              'Gunakan email Anda untuk mengecek status pendaftaran.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width:  double.infinity,
            child:  ElevatedButton(
              onPressed: () {
                Get.offAllNamed('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Kembali ke Login',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
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
        elevation: 0,
        title: const Text(
          'Daftar Merchant Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? size.width * 0.2 : 20,
            vertical:   20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader(Icons.person_outline_rounded, 'Data Pemilik'),
                const SizedBox(height: 12),
                _field(
                  controller: _nameCtrl,
                  label:      'Nama Lengkap',
                  hint:       'Masukkan nama lengkap Anda',
                  icon:       Icons.person_outline_rounded,
                  validator:  (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                _field(
                  controller:  _emailCtrl,
                  label:       'Email',
                  hint:        'Masukkan email aktif Anda',
                  icon:        Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator:   (v) {
                    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                    if (!GetUtils.isEmail(v.trim())) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  controller:  _phoneCtrl,
                  label:       'No. HP (opsional)',
                  hint:        'Contoh: 08123456789',
                  icon:        Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: _passwordCtrl,
                  label:      'Password',
                  hint:       'Minimal 8 karakter',
                  obscure:    _obscurePw,
                  onToggle:   () => setState(() => _obscurePw = !_obscurePw),
                  validator:  (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    if (v.length < 8) return 'Password minimal 8 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: _confirmPwCtrl,
                  label:      'Konfirmasi Password',
                  hint:       'Ulangi password Anda',
                  obscure:    _obscureConfirm,
                  onToggle:   () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator:  (v) {
                    if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
                    if (v != _passwordCtrl.text) return 'Password tidak cocok';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _sectionHeader(Icons.store_outlined, 'Data Usaha'),
                const SizedBox(height: 12),
                _field(
                  controller: _merchantNameCtrl,
                  label:      'Nama Usaha',
                  hint:       'Contoh: Toko Baju Sejahtera',
                  icon:       Icons.store_outlined,
                  validator:  (v) => (v == null || v.trim().isEmpty) ? 'Nama usaha wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _businessTypeCtrl,
                  label:      'Jenis Usaha (opsional)',
                  hint:       'Contoh: Retail, Kuliner, Jasa',
                  icon:       Icons.category_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _addressCtrl,
                  label:      'Alamat (opsional)',
                  hint:       'Alamat usaha Anda',
                  icon:       Icons.location_on_outlined,
                  maxLines:   3,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation:       3,
                      shadowColor:     _accent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Kirim Pendaftaran',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Get.offAllNamed('/login'),
                    child: const Text(
                      'Sudah punya akun? Masuk',
                      style: TextStyle(color: _accent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding:    const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accent, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize:   16,
            fontWeight: FontWeight.bold,
            color:      _darkText,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      validator:    validator,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDeco(label: label, hint: hint, icon: icon),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:  controller,
      validator:   validator,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDeco(
        label: label,
        hint:  hint,
        icon:  Icons.lock_outline,
        suffixIcon: IconButton(
          icon:      Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size:  20,
            color: Colors.grey[600],
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText:  label,
      labelStyle: const TextStyle(fontSize: 14),
      hintText:   hint,
      hintStyle:  TextStyle(fontSize: 13, color: Colors.grey[400]),
      prefixIcon: Icon(icon, size: 20, color: _accent),
      suffixIcon: suffixIcon,
      border:  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.red),
      ),
      filled:    true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
