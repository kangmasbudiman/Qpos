import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/branch_model.dart';
import '../../services/auth/auth_service.dart';
import '../controllers/auth_controller.dart';
import '../widgets/connectivity_indicator.dart';

class BranchSelectionScreen extends StatefulWidget {
  const BranchSelectionScreen({Key? key}) : super(key: key);

  @override
  State<BranchSelectionScreen> createState() => _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends State<BranchSelectionScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshBranches() async {
    final authService = Get.find<AuthService>();
    setState(() => _isRefreshing = true);
    try {
      final found = await authService.refreshBranches();
      if (!mounted) return;
      if (found) {
        Get.snackbar(
          'Berhasil',
          'Cabang berhasil dimuat. Silakan pilih cabang.',
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      } else if (authService.branches.isEmpty) {
        Get.snackbar(
          'Belum Ada Cabang',
          'Cabang belum tersedia. Pastikan admin sudah menambahkan cabang di dashboard.',
          backgroundColor: Colors.orange.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller  = Get.find<AuthController>();
    final authService = Get.find<AuthService>();
    final size        = MediaQuery.of(context).size;
    final isTablet    = size.width >= 600;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient + konten ────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42), Color(0xFFFFA559)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(authService, size),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(top: size.height * 0.02),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.only(
                          topLeft:  Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              size.width * 0.06,
                              size.height * 0.03,
                              size.width * 0.06,
                              size.height * 0.01,
                            ),
                            child: Text(
                              'Pilih Cabang',
                              style: TextStyle(
                                fontSize:   isTablet ? 22 : 18,
                                fontWeight: FontWeight.bold,
                                color:      const Color(0xFF2D3142),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                            child: Text(
                              'Pilih cabang yang ingin Anda kelola hari ini',
                              style: TextStyle(
                                fontSize: isTablet ? 14 : 13,
                                color:    Colors.grey[600],
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),
                          Expanded(
                            child: Obx(() => _buildBranchList(
                              controller, authService, size, isTablet)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ConnectivityDot pojok kanan atas ────────────────────────
          Positioned(
            top:   MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: const ConnectivityDot(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthService authService, Size size) {
    final user = authService.currentUser;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        size.width * 0.06,
        size.height * 0.025,
        size.width * 0.06,
        size.height * 0.01,
      ),
      child: Column(
        children: [
          Container(
            width:  size.width * 0.18,
            height: size.width * 0.18,
            decoration: BoxDecoration(
              color:  Colors.white,
              shape:  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset:     const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.store_rounded,
              size:  size.width * 0.09,
              color: const Color(0xFFFF6B35),
            ),
          ),
          SizedBox(height: size.height * 0.015),
          if (user != null) ...[
            Text(
              user.companyName ?? 'Perusahaan Anda',
              style: const TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.bold,
                color:      Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: size.height * 0.005),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.companyCode ?? '',
                style: const TextStyle(
                  fontSize:      13,
                  color:         Colors.white,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
            SizedBox(height: size.height * 0.008),
            Text(
              'Halo, ${user.name}  •  ${_roleLabel(user.role)}',
              style: TextStyle(
                fontSize: 13,
                color:    Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchList(AuthController controller, AuthService authService,
      Size size, bool isTablet) {
    final branches = authService.branches;

    if (branches.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color:  const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  shape:  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.store_outlined,
                  size:  40,
                  color: Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Belum Ada Cabang',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      Color(0xFF1A1D26),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Akun Anda sudah aktif, namun belum ada\ncabang yang terdaftar untuk merchant ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // ── Tombol Refresh ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRefreshing ? null : _refreshBranches,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_isRefreshing ? 'Memuat...' : 'Coba Refresh Cabang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Info langkah selanjutnya ────────────────────────────
              Container(
                width:      double.infinity,
                padding:    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFF57F17), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Langkah Selanjutnya',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.bold,
                            color:      Color(0xFFF57F17),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildStep('1', 'Login ke web dashboard PAYZEN'),
                    _buildStep('2', 'Buka menu Pengaturan → Cabang'),
                    _buildStep('3', 'Tambahkan minimal 1 cabang'),
                    _buildStep('4', 'Kembali ke sini dan tekan "Refresh"'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => controller.handleLogout(),
                  icon:  const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Kembali ke Login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side:    BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape:   RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? size.width * 0.15 : size.width * 0.05,
        vertical:   8,
      ),
      itemCount:    branches.length + 1,
      itemBuilder: (context, index) {
        if (index == branches.length) {
          return _buildLogoutButton(controller, size);
        }
        return _buildBranchCard(context, branches[index], controller, size, isTablet);
      },
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFFFF6B35),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(BuildContext context, Branch branch,
      AuthController controller, Size size, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation:    2,
        shadowColor:  Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => controller.handleSelectBranch(branch),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  width:  isTablet ? 56 : 48,
                  height: isTablet ? 56 : 48,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFFFF6B35),
                    size:  26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: TextStyle(
                          fontSize:   isTablet ? 16 : 15,
                          fontWeight: FontWeight.bold,
                          color:      const Color(0xFF2D3142),
                        ),
                      ),
                      if (branch.city != null && branch.city!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Text(branch.city!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                      if (branch.code != null && branch.code!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('Kode: ${branch.code}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ],
                  ),
                ),
                Container(
                  width:  36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFF6B35).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size:  16,
                    color: Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(AuthController controller, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
      child: Center(
        child: TextButton.icon(
          onPressed: () => controller.handleLogout(),
          icon:  const Icon(Icons.logout_rounded, size: 18, color: Colors.grey),
          label: const Text(
            'Ganti Akun / Logout',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':   return 'Owner';
      case 'manager': return 'Manager';
      case 'cashier': return 'Kasir';
      default:        return role;
    }
  }
}
