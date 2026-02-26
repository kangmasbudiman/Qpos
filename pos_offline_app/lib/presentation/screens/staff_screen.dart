import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../services/auth/auth_service.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _authService = Get.find<AuthService>();
  final _storage     = const FlutterSecureStorage();

  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool _isLoading = false;
  String _search  = '';
  String _roleFilter = 'all'; // all | cashier | manager

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/staff'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list  = List<Map<String, dynamic>>.from(body['data'] as List);
        setState(() {
          _staffList = list;
          _applyFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    _filtered = _staffList.where((s) {
      final name  = (s['name']  as String? ?? '').toLowerCase();
      final email = (s['email'] as String? ?? '').toLowerCase();
      final role  = s['role']   as String? ?? '';
      final q     = _search.toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q) || email.contains(q);
      final matchRole   = _roleFilter == 'all' || role == _roleFilter;
      return matchSearch && matchRole;
    }).toList();
  }

  Future<void> _toggleActive(Map<String, dynamic> staff) async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/staff/${staff['id']}/toggle-active'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        _loadStaff();
        final body     = jsonDecode(res.body) as Map<String, dynamic>;
        final isActive = body['data']?['is_active'] as bool? ?? false;
        Get.snackbar(
          isActive ? 'Diaktifkan' : 'Dinonaktifkan',
          '${staff['name']} berhasil ${isActive ? 'diaktifkan' : 'dinonaktifkan'}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: isActive ? const Color(0xFF4CAF50) : Colors.orange,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (e) {
      debugPrint('Error toggle: $e');
    }
  }

  Future<void> _deleteStaff(Map<String, dynamic> staff) async {
    final confirm = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Hapus Staff', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hapus akun "${staff['name']}"?'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Staff tidak bisa login lagi setelah dihapus.',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Hapus'),
        ),
      ],
    ));

    if (confirm != true) return;

    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;
      final res = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/staff/${staff['id']}'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        _loadStaff();
        Get.snackbar('Berhasil', '${staff['name']} telah dihapus',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF4CAF50),
            colorText: Colors.white,
            margin: const EdgeInsets.all(12));
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        Get.snackbar('Gagal', body['message'] ?? 'Gagal menghapus',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white);
      }
    } catch (e) {
      debugPrint('Error delete: $e');
    }
  }

  // ── Dialog Form ──────────────────────────────────────────────────────────

  void _showForm([Map<String, dynamic>? existing]) {
    final isEdit          = existing != null;
    final nameCtrl        = TextEditingController(text: existing?['name']  ?? '');
    final emailCtrl       = TextEditingController(text: existing?['email'] ?? '');
    final phoneCtrl       = TextEditingController(text: existing?['phone'] ?? '');
    final passCtrl        = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String role           = existing?['role'] ?? 'cashier';
    int? branchId         = existing?['branch_id'] as int?;
    bool isSaving         = false;
    String? formError;
    final branches        = _authService.branches;

    Get.dialog(
      StatefulBuilder(builder: (ctx, setDialog) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: const Color(0xFF2196F3), size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEdit ? 'Edit Staff' : 'Tambah Staff Baru',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D26))),
                            Text(
                              isEdit ? 'Perbarui informasi staff'
                                     : 'Buat akun untuk kasir atau manajer',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : Get.back,
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),

                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (formError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade600, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(formError!,
                                      style: TextStyle(
                                          color: Colors.red.shade700, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),

                        _field(nameCtrl, 'Nama Lengkap', Icons.person_rounded),
                        const SizedBox(height: 14),

                        if (!isEdit) ...[
                          _field(emailCtrl, 'Email', Icons.email_rounded,
                              type: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                        ],

                        _field(phoneCtrl, 'Nomor Telepon (opsional)',
                            Icons.phone_rounded, type: TextInputType.phone),
                        const SizedBox(height: 14),

                        _field(passCtrl,
                            isEdit ? 'Password Baru (opsional)' : 'Password',
                            Icons.lock_rounded,
                            obscure: true,
                            onChanged: (_) => setDialog(() {})),
                        const SizedBox(height: 14),

                        _field(confirmPassCtrl, 'Konfirmasi Password',
                            Icons.lock_outline_rounded,
                            obscure: true,
                            onChanged: (_) => setDialog(() {})),

                        if (passCtrl.text.isNotEmpty && confirmPassCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              children: [
                                Icon(
                                  passCtrl.text == confirmPassCtrl.text
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 14,
                                  color: passCtrl.text == confirmPassCtrl.text
                                      ? const Color(0xFF4CAF50)
                                      : Colors.red.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  passCtrl.text == confirmPassCtrl.text
                                      ? 'Password cocok'
                                      : 'Password tidak cocok',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: passCtrl.text == confirmPassCtrl.text
                                        ? const Color(0xFF4CAF50)
                                        : Colors.red.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Role
                        Text('Role Staff',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _roleChip('cashier', 'Kasir',
                                Icons.point_of_sale_rounded, role,
                                (v) => setDialog(() => role = v))),
                            if (_authService.currentUser?.role == 'owner') ...[
                              const SizedBox(width: 10),
                              Expanded(child: _roleChip('manager', 'Manajer',
                                  Icons.manage_accounts_rounded, role,
                                  (v) => setDialog(() => role = v))),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            role == 'cashier'
                                ? '• Kasir: dapat melakukan transaksi dan pembelian produk'
                                : '• Manajer: akses kasir + kelola produk, laporan, dan staff',
                            style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic),
                          ),
                        ),

                        // Branch selector
                        if (branches.length > 1) ...[
                          const SizedBox(height: 20),
                          Text('Cabang',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int?>(
                            value: branchId,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.location_city_rounded,
                                  size: 18, color: Color(0xFFFF6B35)),
                              filled: true, fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2196F3), width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            items: [
                              const DropdownMenuItem(value: null,
                                  child: Text('Semua Cabang',
                                      style: TextStyle(fontSize: 13))),
                              ...branches.map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name,
                                      style: const TextStyle(fontSize: 13)))),
                            ],
                            onChanged: (v) => setDialog(() => branchId = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade100))),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : Get.back,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Batal', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              setDialog(() => formError = 'Nama tidak boleh kosong');
                              return;
                            }
                            if (!isEdit && emailCtrl.text.trim().isEmpty) {
                              setDialog(() => formError = 'Email tidak boleh kosong');
                              return;
                            }
                            if (!isEdit && passCtrl.text.isEmpty) {
                              setDialog(() => formError = 'Password tidak boleh kosong');
                              return;
                            }
                            if (passCtrl.text.isNotEmpty &&
                                passCtrl.text != confirmPassCtrl.text) {
                              setDialog(() => formError = 'Konfirmasi password tidak cocok');
                              return;
                            }

                            setDialog(() { isSaving = true; formError = null; });

                            try {
                              final token = await _storage.read(
                                  key: AppConstants.authTokenKey);
                              if (token == null) return;

                              final body = <String, dynamic>{
                                'name':  nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'role':  role,
                                if (branchId != null) 'branch_id': branchId,
                                if (passCtrl.text.isNotEmpty)
                                  'password': passCtrl.text,
                                if (!isEdit) 'email': emailCtrl.text.trim(),
                              };

                              final uri = isEdit
                                  ? Uri.parse('${AppConstants.baseUrl}'
                                      '/staff/${existing['id']}')
                                  : Uri.parse('${AppConstants.baseUrl}/staff');

                              final res = isEdit
                                  ? await http.put(uri,
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Accept': 'application/json',
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode(body))
                                  : await http.post(uri,
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Accept': 'application/json',
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode(body));

                              final resp =
                                  jsonDecode(res.body) as Map<String, dynamic>;

                              if (res.statusCode == 200 || res.statusCode == 201) {
                                Get.back();
                                _loadStaff();
                                Get.snackbar(
                                  'Berhasil',
                                  isEdit ? 'Data staff diperbarui'
                                         : 'Staff berhasil ditambahkan',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFF4CAF50),
                                  colorText: Colors.white,
                                  margin: const EdgeInsets.all(12),
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.white),
                                );
                              } else {
                                final errors =
                                    resp['errors'] as Map<String, dynamic>?;
                                final msg = errors?.values.first?.first
                                    ?? resp['message'] ?? 'Gagal';
                                setDialog(() { formError = msg; isSaving = false; });
                              }
                            } catch (e) {
                              setDialog(() {
                                formError = 'Error: $e';
                                isSaving = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white)))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(isEdit
                                        ? Icons.save_rounded
                                        : Icons.person_add_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEdit ? 'Simpan Perubahan' : 'Tambah Staff',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user     = _authService.currentUser;
    final canEdit  = user?.role == 'owner' || user?.role == 'manager';
    final isOwner  = user?.role == 'owner';

    final totalStaff    = _staffList.length;
    final activeStaff   = _staffList.where((s) => s['is_active'] == true).length;
    final cashierCount  = _staffList.where((s) => s['role'] == 'cashier').length;
    final managerCount  = _staffList.where((s) => s['role'] == 'manager').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: const Color(0xFF1E2235),
            foregroundColor: Colors.white,
            actions: [
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.person_add_rounded),
                    tooltip: 'Tambah Staff',
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.group_rounded,
                              color: Color(0xFF2196F3), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Manajemen Staff',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('$totalStaff staff terdaftar',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Stat Cards ──────────────────────────────────────
                Row(
                  children: [
                    _statCard('Total', totalStaff.toString(),
                        Icons.group_rounded, const Color(0xFF2196F3)),
                    const SizedBox(width: 10),
                    _statCard('Aktif', activeStaff.toString(),
                        Icons.check_circle_rounded, const Color(0xFF4CAF50)),
                    const SizedBox(width: 10),
                    _statCard('Kasir', cashierCount.toString(),
                        Icons.point_of_sale_rounded, const Color(0xFFFF6B35)),
                    const SizedBox(width: 10),
                    _statCard('Manajer', managerCount.toString(),
                        Icons.manage_accounts_rounded, const Color(0xFF9C27B0)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Search & Filter ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Search
                      TextField(
                        onChanged: (v) => setState(() {
                          _search = v;
                          _applyFilter();
                        }),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau email...',
                          hintStyle: TextStyle(color: Colors.grey.shade400,
                              fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey.shade400, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Role filter chips
                      Row(
                        children: [
                          Text('Filter: ',
                              style: TextStyle(fontSize: 12,
                                  color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          _filterChip('all', 'Semua'),
                          const SizedBox(width: 6),
                          _filterChip('cashier', 'Kasir'),
                          const SizedBox(width: 6),
                          _filterChip('manager', 'Manajer'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Staff List ──────────────────────────────────────
                _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _filtered.isEmpty
                        ? _emptyState()
                        : Column(
                            children: _filtered.asMap().entries.map((e) =>
                                _staffCard(e.value, canEdit, isOwner)).toList(),
                          ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Tambah Staff',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _roleFilter == value;
    return GestureDetector(
      onTap: () => setState(() { _roleFilter = value; _applyFilter(); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2196F3)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> staff, bool canEdit, bool isOwner) {
    final isActive = staff['is_active'] as bool? ?? true;
    final role     = staff['role'] as String? ?? 'cashier';
    final initial  = (staff['name'] as String? ?? '?').substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.05 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isActive
                      ? _roleColor(role).withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? _roleColor(role)
                              : Colors.grey.shade400)),
                ),
                if (!isActive)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          staff['name'] as String? ?? '-',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? const Color(0xFF1A1D26)
                                  : Colors.grey.shade400),
                        ),
                      ),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _roleColor(role).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role == 'manager' ? 'Manajer' : 'Kasir',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _roleColor(role)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(staff['email'] as String? ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  if ((staff['phone'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 11,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(staff['phone'] as String,
                            style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            if (canEdit)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.grey.shade400, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  _popupItem('edit', 'Edit',
                      Icons.edit_rounded, const Color(0xFF2196F3)),
                  _popupItem('toggle',
                      isActive ? 'Nonaktifkan' : 'Aktifkan',
                      isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                      isActive ? Colors.orange : Colors.green),
                  if (isOwner)
                    _popupItem('delete', 'Hapus',
                        Icons.delete_rounded, Colors.red.shade600),
                ],
                onSelected: (action) {
                  if (action == 'edit') _showForm(staff);
                  if (action == 'toggle') _toggleActive(staff);
                  if (action == 'delete') _deleteStaff(staff);
                },
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(_search.isNotEmpty ? 'Tidak ada hasil pencarian'
                                  : 'Belum ada staff terdaftar',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          if (_search.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Tambah Staff Pertama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    return role == 'manager' ? const Color(0xFF9C27B0) : const Color(0xFF2196F3);
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text,
       bool obscure = false,
       void Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFFF6B35)),
        filled: true, fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _roleChip(String value, String label, IconData icon,
      String selected, void Function(String) onTap) {
    final isSel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFF2196F3).withValues(alpha: 0.10)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? const Color(0xFF2196F3) : Colors.grey.shade200,
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18,
                color: isSel ? const Color(0xFF2196F3) : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                    color: isSel ? const Color(0xFF2196F3) : Colors.grey.shade600)),
            if (isSel) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: Color(0xFF2196F3)),
            ],
          ],
        ),
      ),
    );
  }
}
