import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/payzen_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  int _tapCount = 0;
  DateTime? _lastTap;
  static const _requiredTaps = 5;
  static const _tapWindow    = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 32, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          isTablet
              ? _buildTabletLayout(controller, size)
              : _buildPhoneLayout(controller, size),
          Positioned(
            top:   MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: const ConnectivityDot(),
          ),
        ],
      ),
    );
  }

  // ── TABLET: kiri dark navy, kanan form putih ─────────────────────────────
  Widget _buildTabletLayout(AuthController controller, Size size) {
    return Row(
      children: [
        // Panel kiri — dark navy, logo + fitur
        SizedBox(
          width: size.width * 0.46,
          child: _buildBrandingSection(size),
        ),
        // Panel kanan — putih bersih, form login
        Expanded(
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: Opacity(opacity: _fadeAnim.value, child: child),
                  ),
                  child: _buildFormSection(controller, size, true),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PHONE: dark navy header, form di bawah ───────────────────────────────
  Widget _buildPhoneLayout(AuthController controller, Size size) {
    return Column(
      children: [
        // Header navy dengan logo
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1D2E),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
            24, MediaQuery.of(context).padding.top + 32, 24, 32,
          ),
          child: GestureDetector(
            onTap: _onLogoTap,
            behavior: HitTestBehavior.opaque,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const PayzenLogo.horizontal(
                    size: 52,
                    ringColor: Colors.white,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'POS & Payment Solution',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Form section
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: Opacity(opacity: _fadeAnim.value, child: child),
              ),
              child: _buildFormSection(controller, size, false),
            ),
          ),
        ),
      ],
    );
  }

  // ── Branding panel kiri (tablet) ─────────────────────────────────────────
  Widget _buildBrandingSection(Size size) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1D2E),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                GestureDetector(
                  onTap: _onLogoTap,
                  behavior: HitTestBehavior.opaque,
                  child: const PayzenLogo.horizontal(
                    size: 56,
                    ringColor: Colors.white,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'POS & Payment Solution',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 48),

                // Tagline
                const Text(
                  'Kelola bisnis Anda\nlebih mudah & cepat.',
                  style: TextStyle(
                    fontSize:   26,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                    height:     1.3,
                  ),
                ),

                const SizedBox(height: 36),

                // Feature list
                _featureItem(Icons.business_rounded,
                    'Multi-Tenant', 'Satu platform untuk semua klien Anda'),
                const SizedBox(height: 18),
                _featureItem(Icons.wifi_off_rounded,
                    'Offline First', 'Tetap berjalan tanpa internet'),
                const SizedBox(height: 18),
                _featureItem(Icons.sync_rounded,
                    'Auto Sync', 'Data sinkron otomatis saat online'),
                const SizedBox(height: 18),
                _featureItem(Icons.store_rounded,
                    'Multi-Cabang', 'Kelola banyak cabang dengan mudah'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding:    const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        const Color(0xFFE8460A).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFE8460A), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Form Section ─────────────────────────────────────────────────────────
  Widget _buildFormSection(AuthController controller, Size size, bool isTablet) {
    return Obx(() => controller.companyVerified.value
        ? _buildLoginStep(controller, size, isTablet)
        : _buildCompanyStep(controller, size, isTablet));
  }

  // ── STEP 1: Company Code ─────────────────────────────────────────────────
  Widget _buildCompanyStep(AuthController controller, Size size, bool isTablet) {
    final double titleSize    = isTablet ? 22 : 20;
    final double subtitleSize = isTablet ? 14 : 13;
    final double btnHeight    = isTablet ? 52 : size.height * 0.065;

    return Form(
      key: controller.companyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:       MainAxisSize.min,
        children: [
          Text('Selamat Datang!',
              style: TextStyle(
                fontSize:   titleSize,
                fontWeight: FontWeight.w800,
                color:      const Color(0xFF1A1D2E),
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Masukkan kode company Anda',
              style: TextStyle(fontSize: subtitleSize, color: Colors.grey[500]),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),

          TextFormField(
            controller: controller.companyCodeController,
            validator:  controller.validateCompanyCode,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: subtitleSize, fontWeight: FontWeight.w600, letterSpacing: 3,
            ),
            decoration: _inputDecoration(
              label:    'Kode Company',
              hint:     'Contoh: TOKO1234',
              icon:     Icons.business_rounded,
              fontSize: subtitleSize,
            ),
          ),
          const SizedBox(height: 20),

          Obx(() => SizedBox(
            height: btnHeight,
            child: ElevatedButton(
              onPressed: controller.isLoading ? null : controller.handleLookupCompany,
              style: _btnStyle(),
              child: controller.isLoading
                  ? _loadingIndicator(btnHeight)
                  : Text('Lanjutkan',
                      style: TextStyle(
                        fontSize: subtitleSize * 1.1, fontWeight: FontWeight.bold,
                      )),
            ),
          )),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Kode company diberikan oleh admin sistem',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Belum punya akun? ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              GestureDetector(
                onTap: () => Get.toNamed('/register'),
                child: const Text('Daftar Sekarang',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: Color(0xFFE8460A),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => Get.toNamed('/check-registration'),
              child: const Text('Cek status pendaftaran',
                  style: TextStyle(
                    fontSize: 12, color: Color(0xFFE8460A),
                    decoration: TextDecoration.underline,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Email + Password ─────────────────────────────────────────────
  Widget _buildLoginStep(AuthController controller, Size size, bool isTablet) {
    final double titleSize    = isTablet ? 22 : 20;
    final double subtitleSize = isTablet ? 14 : 13;
    final double btnHeight    = isTablet ? 52 : size.height * 0.065;

    return Form(
      key: controller.loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:       MainAxisSize.min,
        children: [
          _buildCompanyBadge(controller, subtitleSize),
          const SizedBox(height: 24),

          Text('Masuk',
              style: TextStyle(
                fontSize: titleSize, fontWeight: FontWeight.w800,
                color:    const Color(0xFF1A1D2E),
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Masukkan kredensial akun Anda',
              style: TextStyle(fontSize: subtitleSize, color: Colors.grey[500]),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),

          TextFormField(
            controller:   controller.emailController,
            validator:    controller.validateEmail,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: subtitleSize),
            decoration: _inputDecoration(
              label: 'Email', hint: 'Masukkan email Anda',
              icon: Icons.email_outlined, fontSize: subtitleSize,
            ),
          ),
          const SizedBox(height: 14),

          Obx(() => TextFormField(
            controller:  controller.passwordController,
            validator:   controller.validatePassword,
            obscureText: controller.obscurePassword.value,
            style: TextStyle(fontSize: subtitleSize),
            decoration: _inputDecoration(
              label: 'Password', hint: 'Masukkan password Anda',
              icon: Icons.lock_outline, fontSize: subtitleSize,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscurePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20, color: Colors.grey[500],
                ),
                onPressed: controller.togglePasswordVisibility,
              ),
            ),
          )),
          const SizedBox(height: 10),

          Obx(() => Row(
            children: [
              SizedBox(
                height: 24, width: 24,
                child: Checkbox(
                  value:       controller.rememberMe.value,
                  onChanged:   (_) => controller.toggleRememberMe(),
                  activeColor: const Color(0xFFE8460A),
                ),
              ),
              const SizedBox(width: 8),
              Text('Ingat saya',
                  style: TextStyle(fontSize: subtitleSize, color: Colors.grey[600])),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed('/forgot-password'),
                child: Text('Lupa Password?',
                    style: TextStyle(
                      fontSize: subtitleSize, fontWeight: FontWeight.w600,
                      color: const Color(0xFFE8460A),
                    )),
              ),
            ],
          )),
          const SizedBox(height: 20),

          Obx(() => SizedBox(
            height: btnHeight,
            child: ElevatedButton(
              onPressed: controller.isLoading ? null : controller.handleLogin,
              style: _btnStyle(),
              child: controller.isLoading
                  ? _loadingIndicator(btnHeight)
                  : Text('Masuk',
                      style: TextStyle(
                        fontSize: subtitleSize * 1.1, fontWeight: FontWeight.bold,
                      )),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCompanyBadge(AuthController controller, double fontSize) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF1A1D2E).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFF1A1D2E).withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, color: Color(0xFF1A1D2E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(controller.companyName.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14,
                      color: Color(0xFF1A1D2E),
                    ))),
                Obx(() => Text(controller.verifiedCode.value,
                    style: TextStyle(
                      fontSize: 11, color: Colors.grey[500], letterSpacing: 2,
                    ))),
              ],
            ),
          ),
          GestureDetector(
            onTap: controller.resetCompanyStep,
            child: Container(
              padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        const Color(0xFF1A1D2E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Ganti',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E), fontSize: 12, fontWeight: FontWeight.w600,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required double fontSize,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText:  label,
      labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[600]),
      hintText:   hint,
      hintStyle:  TextStyle(fontSize: fontSize * 0.9, color: Colors.grey[400]),
      prefixIcon: Icon(icon, size: fontSize * 1.4, color: const Color(0xFF1A1D2E).withValues(alpha: 0.5)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Color(0xFF1A1D2E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Colors.red),
      ),
      filled:    true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _btnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A1D2E),
      foregroundColor: Colors.white,
      elevation:       0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _loadingIndicator(double btnHeight) {
    return SizedBox(
      height: btnHeight * 0.4,
      width:  btnHeight * 0.4,
      child:  const CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
