import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/branch_model.dart';
import '../../services/auth/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  // Form controllers
  final companyCodeController = TextEditingController();
  final emailController       = TextEditingController();
  final passwordController    = TextEditingController();

  // Super admin form controllers
  final emailSuperAdminController    = TextEditingController();
  final passwordSuperAdminController = TextEditingController();

  // Form keys
  final companyFormKey   = GlobalKey<FormState>();
  final loginFormKey     = GlobalKey<FormState>();
  final superAdminFormKey = GlobalKey<FormState>();

  // Alias agar kode lama yang pakai formKey tidak error
  GlobalKey<FormState> get formKey => loginFormKey;

  // State
  final RxBool rememberMe       = true.obs;
  final RxBool obscurePassword  = true.obs;

  // Step 1: setelah lookup company berhasil
  final RxBool companyVerified     = false.obs;
  final RxString companyName       = ''.obs;
  final RxString verifiedCode      = ''.obs;

  // Getters dari service
  bool          get isLoading     => _authService.isLoading;
  bool          get isLoggedIn    => _authService.isLoggedIn;
  List<Branch>  get branches      => _authService.branches;
  Branch?       get selectedBranch=> _authService.selectedBranch;

  @override
  void onClose() {
    companyCodeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    emailSuperAdminController.dispose();
    passwordSuperAdminController.dispose();
    super.onClose();
  }

  // ─────────────────────────────────────────────
  // STEP 1: Verifikasi kode company
  // ─────────────────────────────────────────────

  Future<void> handleLookupCompany() async {
    if (!companyFormKey.currentState!.validate()) return;

    final code = companyCodeController.text.trim().toUpperCase();

    try {
      final result = await _authService.lookupCompany(code);
      if (result != null) {
        companyName.value    = result['company_name'] as String;
        verifiedCode.value   = code;
        companyVerified.value = true;
      }
    } catch (e) {
      Get.snackbar(
        'Kode Company Tidak Valid',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  /// Reset ke step 1 (ganti company)
  void resetCompanyStep() {
    companyVerified.value = false;
    companyName.value     = '';
    verifiedCode.value    = '';
    emailController.clear();
    passwordController.clear();
    obscurePassword.value = true;
  }

  // ─────────────────────────────────────────────
  // STEP 2: Login
  // ─────────────────────────────────────────────

  Future<void> handleLogin() async {
    if (!loginFormKey.currentState!.validate()) return;

    final result = await _authService.login(
      companyCode: verifiedCode.value,
      email:       emailController.text.trim(),
      password:    passwordController.text,
      rememberMe:  rememberMe.value,
    );

    switch (result) {
      case LoginResult.needBranchSelection:
        // Cashier tidak boleh pilih cabang — langsung ke dashboard
        if (_authService.currentUser?.isCashier == true) {
          _navigateAfterLogin();
        } else {
          Get.offAllNamed('/branch-selection');
        }
        break;
      case LoginResult.success:
        _navigateAfterLogin();
        break;
      case LoginResult.failed:
        break;
    }
  }

  /// Navigasi setelah login berhasil — cek subscription dulu
  void _navigateAfterLogin() {
    final user = _authService.currentUser;

    // Super admin → panel khusus (tidak perlu cek subscription)
    if (user?.isSuperAdmin == true) {
      Get.offAllNamed('/super-admin');
      return;
    }

    // Cek subscription — expired/suspended → halaman terkunci
    final sub = _authService.subscription;
    if (sub != null && !sub.canAccess) {
      Get.offAllNamed('/subscription-expired');
      return;
    }

    Get.offAllNamed('/dashboard');
  }

  // ─────────────────────────────────────────────
  // SUPER ADMIN LOGIN
  // ─────────────────────────────────────────────

  Future<void> handleLoginSuperAdmin() async {
    if (!superAdminFormKey.currentState!.validate()) return;

    final result = await _authService.loginSuperAdmin(
      email:    emailSuperAdminController.text.trim(),
      password: passwordSuperAdminController.text,
    );

    if (result == LoginResult.success) {
      Get.offAllNamed('/super-admin');
    }
  }

  // ─────────────────────────────────────────────
  // STEP 3: Pilih cabang
  // ─────────────────────────────────────────────

  Future<void> handleSelectBranch(Branch branch) async {
    await _authService.selectBranch(branch);
    _navigateAfterLogin();
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────

  Future<void> handleLogout() async {
    await _authService.logout();
    companyVerified.value = false;
    companyName.value     = '';
    verifiedCode.value    = '';
    Get.offAllNamed('/login');
  }

  // ─────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────

  void togglePasswordVisibility() => obscurePassword.value = !obscurePassword.value;
  void toggleRememberMe()         => rememberMe.value = !rememberMe.value;

  String? validateCompanyCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Kode company wajib diisi';
    if (value.trim().length < 6) return 'Kode company minimal 6 karakter';
    return null;
  }

  String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email wajib diisi';
    if (!GetUtils.isEmail(email)) return 'Format email tidak valid';
    return null;
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password wajib diisi';
    if (password.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  void clearForm() {
    emailController.clear();
    passwordController.clear();
    obscurePassword.value = true;
  }
}
