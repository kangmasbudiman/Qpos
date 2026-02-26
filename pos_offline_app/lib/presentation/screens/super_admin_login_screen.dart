import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../widgets/connectivity_indicator.dart';

class SuperAdminLoginScreen extends StatelessWidget {
  const SuperAdminLoginScreen({Key? key}) : super(key: key);

  static const _dark   = Color(0xFF1E2235);
  static const _darker = Color(0xFF2D3154);
  static const _accent = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final size       = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [_dark, _darker],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width >= 600 ? size.width * 0.25 : size.width * 0.07,
                    vertical:   24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ──────────────────────────────────────────
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color:  _accent,
                          shape:  BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:      _accent.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset:     const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white, size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Super Admin',
                        style: TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.bold,
                          color:      Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Panel Manajemen Sistem',
                        style: TextStyle(
                          fontSize: 13,
                          color:    Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Form Card ──────────────────────────────────────
                      Container(
                        padding:    EdgeInsets.all(size.width * 0.07),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:      Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset:     const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: controller.superAdminFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Masuk sebagai Admin',
                                style: TextStyle(
                                  fontSize:   16,
                                  fontWeight: FontWeight.bold,
                                  color:      Color(0xFF2D3142),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),

                              // Email
                              TextFormField(
                                controller:   controller.emailSuperAdminController,
                                validator:    controller.validateEmail,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Email Admin',
                                  hint:  'admin@sistem.com',
                                  icon:  Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Password
                              Obx(() => TextFormField(
                                controller:  controller.passwordSuperAdminController,
                                validator:   controller.validatePassword,
                                obscureText: controller.obscurePassword.value,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  hint:  'Masukkan password',
                                  icon:  Icons.lock_outline,
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
                              const SizedBox(height: 24),

                              // Login button
                              Obx(() => SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: controller.isLoading
                                      ? null
                                      : controller.handleLoginSuperAdmin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _dark,
                                    foregroundColor: Colors.white,
                                    elevation:       3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: controller.isLoading
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Masuk',
                                          style: TextStyle(
                                            fontSize:   15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Text(
                          'Kembali ke login merchant',
                          style: TextStyle(
                            fontSize:   12,
                            color:      Colors.white.withValues(alpha: 0.7),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Connectivity dot
          Positioned(
            top:   MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: const ConnectivityDot(),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String  label,
    required String  hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText:  label,
      labelStyle: const TextStyle(fontSize: 14),
      hintText:   hint,
      hintStyle:  TextStyle(fontSize: 13, color: Colors.grey[400]),
      prefixIcon: Icon(icon, size: 20, color: _dark),
      suffixIcon: suffixIcon,
      border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: _dark, width: 2),
      ),
      filled:    true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
