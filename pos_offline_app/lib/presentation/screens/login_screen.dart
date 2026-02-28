import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../widgets/connectivity_indicator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Secret tap counter untuk akses super admin
  int _tapCount = 0;
  DateTime? _lastTap;
  static const _requiredTaps = 5;
  static const _tapWindow    = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!) > _tapWindow) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTap = now;

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _lastTap  = null;
      Get.toNamed('/super-admin-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthController());
    final size       = MediaQuery.of(context).size;
    final isTablet   = size.width >= 600;

    return Scaffold(
      body: Stack(
        children: [
          isTablet
              ? _buildTabletLayout(controller, size)
              : _buildPhoneLayout(controller, size),
          // Dot kecil di pojok kanan atas
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: const ConnectivityDot(),
          ),
        ],
      ),
    );
  }

  // ── Layouts ─────────────────────────────────────────────────────────────

  Widget _buildTabletLayout(AuthController controller, Size size) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildBrandingSection(size, true)),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
                child: _buildFormSection(controller, size, true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(AuthController controller, Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42), Color(0xFFFFA559)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.07,
              vertical:   size.height * 0.02,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(size.width * 0.22),
                SizedBox(height: size.height * 0.015),
                const Text(
                  'PAYZEN',
                  style: TextStyle(
                    fontSize:   24,
                    fontWeight: FontWeight.bold,
                    color:      Colors.white,
                  ),
                ),
                SizedBox(height: size.height * 0.025),
                Container(
                  padding: EdgeInsets.all(size.width * 0.07),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset:     const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _buildFormSection(controller, size, false),
                ),
                SizedBox(height: size.height * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Branding (tablet left side) ─────────────────────────────────────────

  Widget _buildBrandingSection(Size size, bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42), Color(0xFFFFA559)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(size.width * 0.06),
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLogo(size.width * 0.12),
                const SizedBox(height: 16),
                const Text(
                  'PAYZEN',
                  style: TextStyle(
                    fontSize:   28,
                    fontWeight: FontWeight.bold,
                    color:      Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Reliable POS & Payment Solution',
                  style: TextStyle(
                    fontSize: 14,
                    color:    Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _featureItem(Icons.business_rounded,
                    'Multi-Tenant', 'Satu platform untuk semua klien Anda'),
                const SizedBox(height: 16),
                _featureItem(Icons.wifi_off_rounded,
                    'Offline First', 'Tetap berjalan tanpa internet'),
                const SizedBox(height: 16),
                _featureItem(Icons.sync_rounded,
                    'Auto Sync', 'Data sinkron otomatis saat online'),
                const SizedBox(height: 16),
                _featureItem(Icons.store_rounded,
                    'Multi-Cabang', 'Kelola banyak cabang dengan mudah'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double size) {
    return GestureDetector(
      onTap:     _onLogoTap,
      behavior:  HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color:  Colors.white,
            shape:  BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.point_of_sale_rounded,
            size:  size * 0.5,
            color: const Color(0xFFFF6B35),
          ),
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding:     const EdgeInsets.all(10),
          decoration:  BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Form Section (2-step) ────────────────────────────────────────────────

  Widget _buildFormSection(AuthController controller, Size size, bool isTablet) {
    return Obx(() => controller.companyVerified.value
        ? _buildLoginStep(controller, size, isTablet)
        : _buildCompanyStep(controller, size, isTablet));
  }

  // ── STEP 1: Company Code ─────────────────────────────────────────────────

  Widget _buildCompanyStep(AuthController controller, Size size, bool isTablet) {
    final double titleSize    = isTablet ? 20 : 18;
    final double subtitleSize = isTablet ? 14 : 13;
    final double btnHeight    = size.height * 0.065;

    return Form(
      key: controller.companyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:       MainAxisSize.min,
        children: [
          // Title
          Text('Selamat Datang!',
              style: TextStyle(
                fontSize:   titleSize,
                fontWeight: FontWeight.bold,
                color:      const Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Masukkan kode company Anda',
              style: TextStyle(fontSize: subtitleSize, color: Colors.grey[600]),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // Company Code field
          TextFormField(
            controller: controller.companyCodeController,
            validator:  controller.validateCompanyCode,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize:      subtitleSize,
              fontWeight:    FontWeight.w600,
              letterSpacing: 3,
            ),
            decoration: _inputDecoration(
              label:    'Kode Company',
              hint:     'Contoh: TOKO1234',
              icon:     Icons.business_rounded,
              fontSize: subtitleSize,
            ),
          ),
          const SizedBox(height: 20),

          // Tombol Lanjutkan
          Obx(() => SizedBox(
            height: btnHeight,
            child: ElevatedButton(
              onPressed: controller.isLoading ? null : controller.handleLookupCompany,
              style: _btnStyle(),
              child: controller.isLoading
                  ? _loadingIndicator(btnHeight)
                  : Text('Lanjutkan',
                      style: TextStyle(
                        fontSize:   subtitleSize * 1.1,
                        fontWeight: FontWeight.bold,
                      )),
            ),
          )),
          const SizedBox(height: 12),

          // Info
          Center(
            child: Text(
              'Kode company diberikan oleh admin sistem',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 4),

          // Link Daftar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Belum punya akun? ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              GestureDetector(
                onTap: () => Get.toNamed('/register'),
                child: const Text(
                  'Daftar Sekarang',
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFFFF6B35),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Link Cek Status
          Center(
            child: GestureDetector(
              onTap: () => Get.toNamed('/check-registration'),
              child: const Text(
                'Cek status pendaftaran',
                style: TextStyle(
                  fontSize:   12,
                  color:      Color(0xFFFF6B35),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Email + Password ─────────────────────────────────────────────

  Widget _buildLoginStep(AuthController controller, Size size, bool isTablet) {
    final double titleSize    = isTablet ? 20 : 18;
    final double subtitleSize = isTablet ? 14 : 13;
    final double btnHeight    = size.height * 0.065;

    return Form(
      key: controller.loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:       MainAxisSize.min,
        children: [
          // Company badge + back button
          _buildCompanyBadge(controller, subtitleSize),
          const SizedBox(height: 20),

          Text('Masuk',
              style: TextStyle(
                fontSize:   titleSize,
                fontWeight: FontWeight.bold,
                color:      const Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Masukkan kredensial akun Anda',
              style: TextStyle(fontSize: subtitleSize, color: Colors.grey[600]),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),

          // Email field
          TextFormField(
            controller:  controller.emailController,
            validator:   controller.validateEmail,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: subtitleSize),
            decoration: _inputDecoration(
              label: 'Email',
              hint:  'Masukkan email Anda',
              icon:  Icons.email_outlined,
              fontSize: subtitleSize,
            ),
          ),
          const SizedBox(height: 14),

          // Password field
          Obx(() => TextFormField(
            controller:  controller.passwordController,
            validator:   controller.validatePassword,
            obscureText: controller.obscurePassword.value,
            style: TextStyle(fontSize: subtitleSize),
            decoration: _inputDecoration(
              label: 'Password',
              hint:  'Masukkan password Anda',
              icon:  Icons.lock_outline,
              fontSize: subtitleSize,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscurePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size:  20,
                  color: Colors.grey[600],
                ),
                onPressed: controller.togglePasswordVisibility,
              ),
            ),
          )),
          const SizedBox(height: 10),

          // Remember me + Lupa Password
          Obx(() => Row(
            children: [
              SizedBox(
                height: 24, width: 24,
                child: Checkbox(
                  value:       controller.rememberMe.value,
                  onChanged:   (_) => controller.toggleRememberMe(),
                  activeColor: const Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 8),
              Text('Ingat saya',
                  style: TextStyle(fontSize: subtitleSize, color: Colors.grey[700])),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed('/forgot-password'),
                child: Text(
                  'Lupa Password?',
                  style: TextStyle(
                    fontSize:   subtitleSize,
                    color:      const Color(0xFFFF6B35),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )),
          const SizedBox(height: 18),

          // Login button
          Obx(() => SizedBox(
            height: btnHeight,
            child: ElevatedButton(
              onPressed: controller.isLoading ? null : controller.handleLogin,
              style: _btnStyle(),
              child: controller.isLoading
                  ? _loadingIndicator(btnHeight)
                  : Text('Masuk',
                      style: TextStyle(
                        fontSize:   subtitleSize * 1.1,
                        fontWeight: FontWeight.bold,
                      )),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCompanyBadge(AuthController controller, double fontSize) {
    return Container(
      padding:     const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:  BoxDecoration(
        color:        const Color(0xFFFF6B35).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, color: Color(0xFFFF6B35), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(
                  controller.companyName.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                    color:      Color(0xFF2D3142),
                  ),
                )),
                Obx(() => Text(
                  controller.verifiedCode.value,
                  style: const TextStyle(
                    fontSize:      11,
                    color:         Color(0xFFFF6B35),
                    letterSpacing: 2,
                  ),
                )),
              ],
            ),
          ),
          // Tombol ganti company
          GestureDetector(
            onTap: controller.resetCompanyStep,
            child: Container(
              padding:     const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration:  BoxDecoration(
                color:        const Color(0xFFFF6B35).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Ganti',
                style: TextStyle(
                  color:      Color(0xFFFF6B35),
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required double fontSize,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText:  label,
      labelStyle: TextStyle(fontSize: fontSize),
      hintText:   hint,
      hintStyle:  TextStyle(fontSize: fontSize * 0.9),
      prefixIcon: Icon(icon, size: fontSize * 1.4, color: const Color(0xFFFF6B35)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Color(0xFFFF6B35), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.red),
      ),
      filled:    true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _btnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFF6B35),
      foregroundColor: Colors.white,
      elevation:       3,
      shadowColor:     const Color(0xFFFF6B35).withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _loadingIndicator(double btnHeight) {
    return SizedBox(
      height: btnHeight * 0.4,
      width:  btnHeight * 0.4,
      child:  const CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
