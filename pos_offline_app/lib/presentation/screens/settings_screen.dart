import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/branch_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/backup/backup_service.dart';
import '../../services/print/bluetooth_printer_service.dart';
import '../../services/shift/shift_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../services/language/language_service.dart';
import '../../services/theme/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = Get.find<AuthService>();
  final _storage     = const FlutterSecureStorage();

  // Form controllers – branch info
  final _nameCtrl    = TextEditingController();
  final _codeCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _cityCtrl    = TextEditingController();

  bool _isSaving  = false;
  bool _isDirty   = false;
  String? _error;

  // Staff management state
  List<Map<String, dynamic>> _staffList = [];
  bool _isLoadingStaff = false;

  // Backup state
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _lastBackupPath;

  // Printer BT state
  bool _isScanningPrinter = false;
  bool _isTestPrinting = false;

  // Shift state
  ShiftService? _shiftSvc;
  Map<String, dynamic>? _currentShift;
  bool _isLoadingShift = false;

  @override
  void initState() {
    super.initState();
    _populateFields();
    final role = _authService.currentUser?.role ?? '';
    if (role == 'owner' || role == 'manager') {
      _loadStaff();
    }
    if (role == 'owner') {
      _authService.refreshBranches();
    }
    try { _shiftSvc = Get.find<ShiftService>(); } catch (_) {}
    _loadCurrentShift();
    // Track dirty state
    for (final ctrl in [_nameCtrl, _codeCtrl, _addressCtrl, _phoneCtrl, _cityCtrl]) {
      ctrl.addListener(() => setState(() => _isDirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _codeCtrl, _addressCtrl, _phoneCtrl, _cityCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFields() {
    final branch = _authService.selectedBranch;
    if (branch == null) return;
    _nameCtrl.text    = branch.name;
    _codeCtrl.text    = branch.code ?? '';
    _addressCtrl.text = branch.address ?? '';
    _phoneCtrl.text   = branch.phone ?? '';
    _cityCtrl.text    = branch.city ?? '';
    setState(() => _isDirty = false);
  }

  Future<void> _saveBranchInfo() async {
    final branch = _authService.selectedBranch;
    if (branch == null) return;

    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nama cabang tidak boleh kosong');
      return;
    }

    setState(() { _isSaving = true; _error = null; });

    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) throw Exception('Sesi berakhir, silakan login ulang');

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/branches/${branch.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'name':    _nameCtrl.text.trim(),
          'code':    _codeCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'phone':   _phoneCtrl.text.trim(),
          'city':    _cityCtrl.text.trim(),
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        // Update AuthService in-memory + SecureStorage (no local branches table)
        final updated = Branch.fromJson(body['data'] as Map<String, dynamic>);
        await _authService.updateSelectedBranch(updated);

        setState(() => _isDirty = false);
        Get.snackbar(
          'Berhasil',
          'Informasi cabang berhasil disimpan',
          snackPosition:   SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF4CAF50),
          colorText:       Colors.white,
          margin:          const EdgeInsets.all(12),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        final msg = body['message'] as String? ?? 'Gagal menyimpan';
        setState(() => _error = msg);
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Staff Methods ───────────────────────────────────────────────────────

  Future<void> _loadStaff() async {
    setState(() => _isLoadingStaff = true);
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/staff'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      debugPrint('Staff response: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(body['data'] as List);
        });
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
    } finally {
      setState(() => _isLoadingStaff = false);
    }
  }

  Future<void> _toggleStaffActive(Map<String, dynamic> staff) async {
    try {
      final token = await _storage.read(key: AppConstants.authTokenKey);
      if (token == null) return;
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/staff/${staff['id']}/toggle-active'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        _loadStaff();
      }
    } catch (e) {
      debugPrint('Error toggle staff: $e');
    }
  }

  Future<void> _deleteStaff(Map<String, dynamic> staff) async {
    final confirm = await Get.dialog<bool>(Builder(builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Staff',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
        content: Text('Hapus "${staff['name']}"? Akun ini tidak bisa login lagi.',
            style: TextStyle(color: isDark ? const Color(0xFF8B8FA8) : null)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false),
              child: Text('Batal',
                  style: TextStyle(color: isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Hapus'),
          ),
        ],
      );
    }));
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
        Get.snackbar('Berhasil', 'Staff dihapus',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF4CAF50),
            colorText: Colors.white);
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        Get.snackbar('Gagal', body['message'] ?? 'Gagal menghapus',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white);
      }
    } catch (e) {
      debugPrint('Error delete staff: $e');
    }
  }

  void _showAddStaffDialog() {
    _showStaffFormDialog(null);
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    _showStaffFormDialog(staff);
  }

  void _showStaffFormDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final nameCtrl  = TextEditingController(text: existing?['name'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final passCtrl        = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String selectedRole = existing?['role'] ?? 'cashier';
    bool isSaving = false;
    String? formError;

    final branches = _authService.branches;
    int? selectedBranchId = existing?['branch_id'] as int?;

    Get.dialog(
      StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
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
                            Text(
                              isEdit ? 'Edit Staff' : 'Tambah Staff Baru',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1D26)),
                            ),
                            Text(
                              isEdit
                                  ? 'Perbarui informasi staff'
                                  : 'Buat akun untuk kasir atau manajer',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving ? null : Get.back,
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                ),

                // ── Form ───────────────────────────────────────────
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

                        _dialogField(nameCtrl, 'Nama Lengkap', Icons.person_rounded),
                        const SizedBox(height: 14),

                        if (!isEdit) ...[
                          _dialogField(emailCtrl, 'Email', Icons.email_rounded,
                              type: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                        ],

                        _dialogField(phoneCtrl, 'Nomor Telepon (opsional)',
                            Icons.phone_rounded, type: TextInputType.phone),
                        const SizedBox(height: 14),

                        _dialogField(
                          passCtrl,
                          isEdit
                              ? 'Password Baru (kosongkan jika tidak diubah)'
                              : 'Password',
                          Icons.lock_rounded,
                          obscure: true,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // Konfirmasi password — selalu tampil
                        if (true) ...[
                          _dialogField(
                            confirmPassCtrl,
                            'Konfirmasi Password',
                            Icons.lock_outline_rounded,
                            obscure: true,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          // Indikator cocok/tidak
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
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 14),

                        // Role selector
                        Text('Role Staff',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _roleChip(
                                'cashier', 'Kasir',
                                Icons.point_of_sale_rounded,
                                selectedRole,
                                (v) => setDialogState(() => selectedRole = v),
                                expanded: true,
                              ),
                            ),
                            if (_authService.currentUser?.role == 'owner') ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: _roleChip(
                                  'manager', 'Manajer',
                                  Icons.manage_accounts_rounded,
                                  selectedRole,
                                  (v) => setDialogState(() => selectedRole = v),
                                  expanded: true,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Role description
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            selectedRole == 'cashier'
                                ? '• Kasir: dapat melakukan transaksi dan pembelian produk'
                                : '• Manajer: akses kasir + kelola produk, laporan, dan staff',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic),
                          ),
                        ),

                        // Branch selector
                        if (branches.length > 1) ...[
                          const SizedBox(height: 20),
                          Text('Cabang',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int?>(
                            value: selectedBranchId,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.location_city_rounded,
                                  size: 18, color: Color(0xFFFF6B35)),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
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
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('Semua Cabang',
                                      style: TextStyle(fontSize: 13))),
                              ...branches.map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name,
                                      style: const TextStyle(fontSize: 13)))),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => selectedBranchId = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Footer / Actions ───────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade100)),
                  ),
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
                              setDialogState(() => formError = 'Nama tidak boleh kosong');
                              return;
                            }
                            if (!isEdit && emailCtrl.text.trim().isEmpty) {
                              setDialogState(() => formError = 'Email tidak boleh kosong');
                              return;
                            }
                            if (!isEdit && passCtrl.text.isEmpty) {
                              setDialogState(() => formError = 'Password tidak boleh kosong');
                              return;
                            }
                            if (passCtrl.text.isNotEmpty &&
                                passCtrl.text != confirmPassCtrl.text) {
                              setDialogState(() => formError = 'Konfirmasi password tidak cocok');
                              return;
                            }

                            setDialogState(() { isSaving = true; formError = null; });

                            try {
                              final token = await _storage.read(key: AppConstants.authTokenKey);
                              if (token == null) return;

                              final body = <String, dynamic>{
                                'name':  nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'role':  selectedRole,
                                if (selectedBranchId != null) 'branch_id': selectedBranchId,
                                if (passCtrl.text.isNotEmpty) 'password': passCtrl.text,
                                if (!isEdit) 'email': emailCtrl.text.trim(),
                              };

                              final uri = isEdit
                                  ? Uri.parse('${AppConstants.baseUrl}/staff/${existing['id']}')
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

                              final resp = jsonDecode(res.body) as Map<String, dynamic>;
                              if (res.statusCode == 200 || res.statusCode == 201) {
                                Get.back();
                                _loadStaff();
                                Get.snackbar(
                                  'Berhasil',
                                  isEdit ? 'Data staff diperbarui' : 'Staff berhasil ditambahkan',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFF4CAF50),
                                  colorText: Colors.white,
                                  margin: const EdgeInsets.all(12),
                                  icon: const Icon(Icons.check_circle, color: Colors.white),
                                );
                              } else {
                                final errors = resp['errors'] as Map<String, dynamic>?;
                                final msg = errors?.values.first?.first
                                    ?? resp['message'] ?? 'Gagal';
                                setDialogState(() { formError = msg; isSaving = false; });
                              }
                            } catch (e) {
                              setDialogState(() { formError = 'Error: $e'; isSaving = false; });
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
                                      valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text(isEdit ? 'Simpan Perubahan' : 'Tambah Staff',
                                        style: const TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false,
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
      String selected, void Function(String) onTap, {bool expanded = false}) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2196F3).withValues(alpha: 0.10)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18,
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade600)),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: Color(0xFF2196F3)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = _authService.selectedBranch;
    final user   = _authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: const Color(0xFF1E2235),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFFF6B35).withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.settings_rounded,
                              color: Color(0xFFFF6B35), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Setelan',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text('Kelola informasi cabang',
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

          // ── Body ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Info Akun (read-only) ──────────────────────────
                _sectionCard(
                  icon: Icons.person_rounded,
                  title: 'Info Akun',
                  color: const Color(0xFF2196F3),
                  child: Column(
                    children: [
                      _infoRow(Icons.badge_rounded, 'Nama',
                          user?.name ?? '-'),
                      _divider(),
                      _infoRow(Icons.email_rounded, 'Email',
                          user?.email ?? '-'),
                      _divider(),
                      _infoRow(Icons.security_rounded, 'Role',
                          _roleLabel(user?.role ?? '')),
                      _divider(),
                      _infoRow(Icons.store_rounded, 'Merchant ID',
                          'ID: ${user?.merchantId ?? '-'}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tampilan (dark mode + language toggle) ────────
                _sectionCard(
                  icon: Icons.palette_rounded,
                  title: AppStrings.t('displaySection'),
                  color: const Color(0xFF9C27B0),
                  child: Obx(() {
                    final themeService    = Get.find<ThemeService>();
                    final langService     = Get.find<LanguageService>();
                    final isDark          = themeService.isDarkMode.value;
                    final isEn            = langService.isEnglish;
                    // subscribe locale agar section ini juga rebuild
                    langService.locale.value;
                    final sectionIsDark = Theme.of(context).brightness == Brightness.dark;
                    return Column(
                      children: [
                        // ── Dark mode toggle ────────────────────────
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF9C27B0).withValues(alpha: 0.20)
                                  : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: isDark ? const Color(0xFF9C27B0) : Colors.amber.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(AppStrings.t('darkMode'),
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: sectionIsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
                          subtitle: Text(
                            isDark
                                ? AppStrings.t('darkModeOn')
                                : AppStrings.t('darkModeOff'),
                            style: TextStyle(
                                fontSize: 11,
                                color: sectionIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                          ),
                          trailing: Switch(
                            value: isDark,
                            onChanged: (_) => themeService.toggleTheme(),
                            activeColor: const Color(0xFF9C27B0),
                          ),
                          onTap: () => themeService.toggleTheme(),
                        ),
                        _divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              _themePreviewChip(
                                label: AppStrings.t('themeLight'),
                                icon: Icons.light_mode_rounded,
                                bgColor: AppColors.lightBackground,
                                textColor: AppColors.lightTextPrimary,
                                borderColor: isDark
                                    ? Colors.grey.shade700
                                    : const Color(0xFF9C27B0),
                                isSelected: !isDark,
                                onTap: () {
                                  if (isDark) themeService.toggleTheme();
                                },
                              ),
                              const SizedBox(width: 10),
                              _themePreviewChip(
                                label: AppStrings.t('themeDark'),
                                icon: Icons.dark_mode_rounded,
                                bgColor: AppColors.darkSurface,
                                textColor: AppColors.darkTextPrimary,
                                borderColor: isDark
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade300,
                                isSelected: isDark,
                                onTap: () {
                                  if (!isDark) themeService.toggleTheme();
                                },
                              ),
                            ],
                          ),
                        ),

                        // ── Language toggle ─────────────────────────
                        const SizedBox(height: 12),
                        _divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.language_rounded,
                                color: Color(0xFF2196F3), size: 20),
                          ),
                          title: Text(AppStrings.t('languageLabel'),
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: sectionIsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
                          subtitle: Text(
                            isEn ? 'English' : 'Bahasa Indonesia',
                            style: TextStyle(
                                fontSize: 11,
                                color: sectionIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                          ),
                          onTap: () {},
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              _langChip(
                                label: 'Indonesia',
                                flag: '🇮🇩',
                                isSelected: !isEn,
                                onTap: () => langService.setLocale('id'),
                              ),
                              const SizedBox(width: 10),
                              _langChip(
                                label: 'English',
                                flag: '🇬🇧',
                                isSelected: isEn,
                                onTap: () => langService.setLocale('en'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // ── Informasi Cabang (editable, owner/manager only) ──
                if (user?.role == 'owner' || user?.role == 'manager')
                _sectionCard(
                  icon: Icons.location_city_rounded,
                  title: 'Informasi Cabang',
                  color: const Color(0xFFFF6B35),
                  trailing: branch != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                          ),
                          child: Text('ID: ${branch.id}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600)),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Builder(builder: (ctx) {
                          final errIsDark = Theme.of(ctx).brightness == Brightness.dark;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: errIsDark
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: errIsDark
                                      ? Colors.red.withValues(alpha: 0.4)
                                      : Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade400, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: errIsDark
                                              ? Colors.red.shade300
                                              : Colors.red.shade700,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        }),

                      _formField(
                        controller: _nameCtrl,
                        label: 'Nama Cabang',
                        icon: Icons.store_rounded,
                        hint: 'Contoh: Cabang Utama',
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      _formField(
                        controller: _codeCtrl,
                        label: 'Kode Cabang',
                        icon: Icons.tag_rounded,
                        hint: 'Contoh: CBG-001',
                      ),
                      const SizedBox(height: 12),
                      _formField(
                        controller: _cityCtrl,
                        label: 'Kota',
                        icon: Icons.location_on_rounded,
                        hint: 'Contoh: Jakarta',
                      ),
                      const SizedBox(height: 12),
                      _formField(
                        controller: _addressCtrl,
                        label: 'Alamat Lengkap',
                        icon: Icons.map_rounded,
                        hint: 'Jl. Contoh No. 123, Kel. ...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _formField(
                        controller: _phoneCtrl,
                        label: 'Nomor Telepon',
                        icon: Icons.phone_rounded,
                        hint: 'Contoh: 021-1234567',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (!_isDirty || _isSaving)
                              ? null
                              : _saveBranchInfo,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _isSaving ? 'Menyimpan...' :
                            !_isDirty  ? 'Tersimpan' : 'Simpan Perubahan',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isDirty
                                ? Colors.grey.shade400
                                : const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),

                      if (_isDirty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: _populateFields,
                            icon: const Icon(Icons.undo_rounded, size: 14),
                            label: const Text('Batalkan perubahan',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ),
                if (user?.role == 'owner' || user?.role == 'manager')
                  const SizedBox(height: 16),

                // ── Manajemen Cabang (owner only) ─────────────────
                if (user?.role == 'owner')
                  _sectionCard(
                    icon:  Icons.account_tree_rounded,
                    title: 'Manajemen Cabang',
                    color: const Color(0xFFFF6B35),
                    child: Obx(() {
                      final count = _authService.branches.length;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Color(0xFFFF6B35), size: 20),
                        ),
                        title: const Text('Tambah & Kelola Cabang',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          count == 0 ? 'Belum ada cabang' : '$count cabang terdaftar',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFFFF6B35)),
                        onTap: () => Get.toNamed('/branch-management')
                            ?.then((_) => _authService.refreshBranches()),
                      );
                    }),
                  ),
                if (user?.role == 'owner') const SizedBox(height: 16),

                // ── Info Struk (owner/manager only) ──────────────
                if (user?.role == 'owner' || user?.role == 'manager')
                Builder(builder: (ctx) {
                  final receiptIsDark = Theme.of(ctx).brightness == Brightness.dark;
                  return _sectionCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Pratinjau Info Struk',
                  color: const Color(0xFF9C27B0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: receiptIsDark ? const Color(0xFF242838) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: receiptIsDark ? const Color(0xFF2E3147) : Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _nameCtrl.text.isNotEmpty
                              ? _nameCtrl.text
                              : 'Nama Cabang',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: receiptIsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26)),
                          textAlign: TextAlign.center,
                        ),
                        if (_cityCtrl.text.isNotEmpty || _addressCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                if (_addressCtrl.text.isNotEmpty) _addressCtrl.text,
                                if (_cityCtrl.text.isNotEmpty) _cityCtrl.text,
                              ].join(', '),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: receiptIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_phoneCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Telp: ${_phoneCtrl.text}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: receiptIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '--------------------------------',
                            style: TextStyle(
                                fontSize: 11,
                                color: receiptIsDark ? const Color(0xFF5A5F7A) : Colors.grey.shade400,
                                letterSpacing: 1),
                          ),
                        ),
                        Text(
                          'Terima Kasih!',
                          style: TextStyle(
                              fontSize: 11,
                              color: receiptIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  );
                }),
                if (user?.role == 'owner' || user?.role == 'manager')
                  const SizedBox(height: 16),

                // ── Manajemen Staff (owner/manager only) ──────────
                if (user?.role == 'owner' || user?.role == 'manager')
                  Builder(builder: (ctx) {
                  final staffIsDark = Theme.of(ctx).brightness == Brightness.dark;
                  return _sectionCard(
                    icon: Icons.group_rounded,
                    title: 'Staff Terbaru',
                    color: const Color(0xFF2196F3),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => Get.toNamed('/staff')
                              ?.then((_) => _loadStaff()),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Lihat Semua',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2196F3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _showAddStaffDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 20),
                          color: const Color(0xFF2196F3),
                          tooltip: 'Tambah Staff',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    child: _isLoadingStaff
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _staffList.isEmpty
                            ? Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Column(
                                      children: [
                                        Icon(Icons.group_off_rounded,
                                            size: 40,
                                            color: staffIsDark
                                                ? const Color(0xFF3A3F5A)
                                                : Colors.grey.shade300),
                                        const SizedBox(height: 8),
                                        Text('Belum ada staff',
                                            style: TextStyle(
                                                color: staffIsDark
                                                    ? const Color(0xFF8B8FA8)
                                                    : Colors.grey.shade500,
                                                fontSize: 13)),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: _showAddStaffDialog,
                                          icon: const Icon(Icons.person_add_rounded, size: 16),
                                          label: const Text('Tambah Staff Pertama'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF2196F3),
                                            side: const BorderSide(color: Color(0xFF2196F3)),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Builder(builder: (_) {
                                // Tampilkan 2 staff terbaru (urut by created_at desc)
                                final sorted = [..._staffList]..sort((a, b) {
                                    final da = a['created_at'] as String? ?? '';
                                    final db = b['created_at'] as String? ?? '';
                                    return db.compareTo(da);
                                  });
                                final preview  = sorted.take(2).toList();
                                final remaining = _staffList.length - preview.length;

                                return Column(
                                  children: [
                                    ...preview.asMap().entries.map((e) {
                                      final idx      = e.key;
                                      final staff    = e.value;
                                      final isActive = staff['is_active'] as bool? ?? true;
                                      final role     = staff['role'] as String? ?? 'cashier';
                                      final initial  = (staff['name'] as String? ?? '?')
                                          .substring(0, 1).toUpperCase();

                                      return Column(
                                        children: [
                                          if (idx > 0)
                                            Divider(height: 1,
                                                color: staffIsDark
                                                    ? const Color(0xFF2A2D3E)
                                                    : Colors.grey.shade100),
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: isActive
                                                      ? (role == 'manager'
                                                          ? (staffIsDark
                                                              ? Colors.purple.withValues(alpha: 0.20)
                                                              : Colors.purple.shade50)
                                                          : (staffIsDark
                                                              ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                                                              : Colors.blue.shade50))
                                                      : (staffIsDark
                                                          ? const Color(0xFF2A2D3E)
                                                          : Colors.grey.shade100),
                                                  child: Text(initial,
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: isActive
                                                              ? (role == 'manager'
                                                                  ? Colors.purple.shade300
                                                                  : const Color(0xFF2196F3))
                                                              : (staffIsDark
                                                                  ? const Color(0xFF5A5F7A)
                                                                  : Colors.grey.shade400))),
                                                ),
                                                Positioned(
                                                  bottom: 0, right: 0,
                                                  child: Container(
                                                    width: 12, height: 12,
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? const Color(0xFF4CAF50)
                                                          : (staffIsDark
                                                              ? const Color(0xFF3A3F5A)
                                                              : Colors.grey.shade400),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: staffIsDark
                                                              ? const Color(0xFF1A1D26)
                                                              : Colors.white,
                                                          width: 2),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    staff['name'] as String? ?? '-',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: isActive
                                                            ? (staffIsDark
                                                                ? const Color(0xFFE8E9EF)
                                                                : const Color(0xFF1A1D26))
                                                            : (staffIsDark
                                                                ? const Color(0xFF5A5F7A)
                                                                : Colors.grey.shade400)),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: role == 'manager'
                                                        ? (staffIsDark
                                                            ? Colors.purple.withValues(alpha: 0.20)
                                                            : Colors.purple.shade50)
                                                        : (staffIsDark
                                                            ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                                                            : Colors.blue.shade50),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    role == 'manager' ? 'Manajer' : 'Kasir',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: role == 'manager'
                                                            ? Colors.purple.shade300
                                                            : const Color(0xFF2196F3)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(staff['email'] as String? ?? '',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: staffIsDark
                                                            ? const Color(0xFF8B8FA8)
                                                            : Colors.grey.shade500)),
                                                if (idx == 0)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFF6B35)
                                                            .withValues(alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(4),
                                                      ),
                                                      child: const Text('Terbaru',
                                                          style: TextStyle(
                                                              fontSize: 9,
                                                              color: Color(0xFFFF6B35),
                                                              fontWeight: FontWeight.w600)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              icon: Icon(Icons.more_vert_rounded,
                                                  size: 18,
                                                  color: staffIsDark
                                                      ? const Color(0xFF5A5F7A)
                                                      : Colors.grey.shade400),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10)),
                                              color: staffIsDark
                                                  ? const Color(0xFF242838)
                                                  : Colors.white,
                                              itemBuilder: (_) => [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(children: [
                                                    const Icon(Icons.edit_rounded,
                                                        size: 16, color: Color(0xFF2196F3)),
                                                    const SizedBox(width: 8),
                                                    Text('Edit',
                                                        style: TextStyle(
                                                            fontSize: 13,
                                                            color: staffIsDark
                                                                ? const Color(0xFFE8E9EF)
                                                                : const Color(0xFF1A1D26))),
                                                  ]),
                                                ),
                                                PopupMenuItem(
                                                  value: 'toggle',
                                                  child: Row(children: [
                                                    Icon(
                                                      isActive
                                                          ? Icons.block_rounded
                                                          : Icons.check_circle_rounded,
                                                      size: 16,
                                                      color: isActive
                                                          ? Colors.orange
                                                          : Colors.green,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                        isActive
                                                            ? 'Nonaktifkan'
                                                            : 'Aktifkan',
                                                        style: TextStyle(
                                                            fontSize: 13,
                                                            color: staffIsDark
                                                                ? const Color(0xFFE8E9EF)
                                                                : const Color(0xFF1A1D26))),
                                                  ]),
                                                ),
                                                if (user?.role == 'owner')
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(children: [
                                                      Icon(Icons.delete_rounded,
                                                          size: 16,
                                                          color: Colors.red.shade600),
                                                      const SizedBox(width: 8),
                                                      Text('Hapus',
                                                          style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors.red.shade600)),
                                                    ]),
                                                  ),
                                              ],
                                              onSelected: (action) {
                                                if (action == 'edit') { _showEditStaffDialog(staff); }
                                                if (action == 'toggle') { _toggleStaffActive(staff); }
                                                if (action == 'delete') { _deleteStaff(staff); }
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }),

                                    // Footer: lihat semua / sisa staff
                                    Divider(height: 1,
                                        color: staffIsDark
                                            ? const Color(0xFF2A2D3E)
                                            : Colors.grey.shade100),
                                    InkWell(
                                      onTap: () => Get.toNamed('/staff')
                                          ?.then((_) => _loadStaff()),
                                      borderRadius: const BorderRadius.vertical(
                                          bottom: Radius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.group_rounded,
                                                size: 15,
                                                color: Color(0xFF2196F3)),
                                            const SizedBox(width: 6),
                                            Text(
                                              remaining > 0
                                                  ? 'Lihat semua staff (+$remaining lainnya)'
                                                  : 'Lihat semua staff',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2196F3),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 16,
                                                color: Color(0xFF2196F3)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                  );
                  }),

                const SizedBox(height: 16),

                // ── Printer Bluetooth ─────────────────────────────
                Builder(builder: (ctx) {
                  final printerDark = Theme.of(ctx).brightness == Brightness.dark;
                  final btService = Get.find<BluetoothPrinterService>();
                  return _sectionCard(
                    icon: Icons.print_rounded,
                    title: 'Printer Bluetooth',
                    color: const Color(0xFF7C3AED),
                    child: Obx(() {
                      final hasPrinter = btService.savedPrinterAddress.value.isNotEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status printer
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: printerDark
                                    ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                                    : const Color(0xFFEDE7F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                hasPrinter ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                                color: hasPrinter ? const Color(0xFF7C3AED) : Colors.grey,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              hasPrinter ? btService.savedPrinterName.value : 'Belum ada printer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: printerDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                              ),
                            ),
                            subtitle: Text(
                              hasPrinter
                                  ? btService.savedPrinterAddress.value
                                  : 'Pilih printer ESC/POS 58mm',
                              style: TextStyle(
                                fontSize: 11,
                                color: printerDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600,
                              ),
                            ),
                            trailing: _isScanningPrinter
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                                : TextButton(
                                    onPressed: () => _scanAndSelectPrinter(btService),
                                    child: Text(
                                      hasPrinter ? 'Ganti' : 'Scan',
                                      style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                          ),

                          // Tombol Test Print & Hapus — tampil jika ada printer
                          if (hasPrinter) ...[
                            Divider(height: 1,
                                color: printerDark ? const Color(0xFF2A2D3E) : Colors.grey.shade100),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: _isTestPrinting ? null : () => _doTestPrint(btService),
                                    icon: _isTestPrinting
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.print_outlined, size: 16, color: Color(0xFF7C3AED)),
                                    label: Text(
                                      _isTestPrinting ? 'Mencetak...' : 'Test Print',
                                      style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 12),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 32,
                                    color: printerDark ? const Color(0xFF2A2D3E) : Colors.grey.shade200),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _clearPrinter(btService),
                                    icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.red),
                                    label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    }),
                  );
                }),

                const SizedBox(height: 16),

                // ── Backup & Data (owner & manager only) ─────────
                if (user?.role == 'owner' || user?.role == 'manager') ...[
                  Builder(builder: (ctx) {
                    final backupDark = Theme.of(ctx).brightness == Brightness.dark;
                    return _sectionCard(
                      icon: Icons.save_rounded,
                      title: 'Backup & Data',
                      color: const Color(0xFF2196F3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: backupDark
                                    ? const Color(0xFF2196F3).withValues(alpha: 0.15)
                                    : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.storage_rounded,
                                  color: Color(0xFF2196F3), size: 20),
                            ),
                            title: Text(
                              'Backup Database',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: backupDark
                                    ? const Color(0xFFE8E9EF)
                                    : const Color(0xFF1A1D26),
                              ),
                            ),
                            subtitle: Text(
                              _lastBackupPath != null
                                  ? 'Terakhir: ${_lastBackupPath!.split('/').last}'
                                  : 'Download backup MySQL hari ini',
                              style: TextStyle(
                                fontSize: 11,
                                color: backupDark
                                    ? const Color(0xFF8B8FA8)
                                    : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _isBackingUp
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2196F3),
                                    ),
                                  )
                                : const Icon(Icons.download_rounded,
                                    color: Color(0xFF2196F3), size: 22),
                            onTap: _isBackingUp ? null : _doBackup,
                          ),

                          // Tombol Share — muncul setelah backup berhasil
                          if (_lastBackupPath != null) ...[
                            Divider(
                              height: 1,
                              color: backupDark
                                  ? const Color(0xFF2A2D3E)
                                  : Colors.grey.shade100,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: backupDark
                                      ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.share_rounded,
                                    color: Color(0xFF4CAF50), size: 20),
                              ),
                              title: Text(
                                'Bagikan File Backup',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: backupDark
                                      ? const Color(0xFFE8E9EF)
                                      : const Color(0xFF1A1D26),
                                ),
                              ),
                              subtitle: Text(
                                _lastBackupPath!.split('/').last,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: backupDark
                                      ? const Color(0xFF8B8FA8)
                                      : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF4CAF50), size: 22),
                              onTap: () => _shareBackup(_lastBackupPath!),
                            ),
                          ],

                          // Tombol Restore — hanya untuk owner
                          if (user?.role == 'owner') ...[
                            Divider(
                              height: 1,
                              color: backupDark
                                  ? const Color(0xFF2A2D3E)
                                  : Colors.grey.shade100,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: backupDark
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isRestoring
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.red,
                                        ),
                                      )
                                    : const Icon(Icons.restore_rounded,
                                        color: Colors.red, size: 20),
                              ),
                              title: Text(
                                _isRestoring ? 'Restoring...' : 'Restore Database',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: backupDark
                                      ? const Color(0xFFE8E9EF)
                                      : const Color(0xFF1A1D26),
                                ),
                              ),
                              subtitle: Text(
                                'Upload file backup untuk restore data',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: backupDark
                                      ? const Color(0xFF8B8FA8)
                                      : Colors.grey.shade600,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.red, size: 22),
                              onTap: _isRestoring ? null : _doRestore,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // ── Shift Kasir ──────────────────────────────────
                if (_shiftSvc != null) ...[
                  _sectionCard(
                    icon: Icons.access_time_rounded,
                    title: 'Shift Kasir',
                    color: const Color(0xFF00BCD4),
                    child: _isLoadingShift
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4)))
                        : Column(
                            children: [
                              // Status shift aktif
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _currentShift != null
                                      ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                                      : Colors.grey.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _currentShift != null
                                          ? Icons.lock_open_rounded
                                          : Icons.lock_rounded,
                                      color: _currentShift != null
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _currentShift != null ? 'Shift Aktif' : 'Tidak Ada Shift',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _currentShift != null
                                                  ? const Color(0xFF4CAF50)
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          if (_currentShift != null)
                                            Text(
                                              'Modal: Rp ${(_currentShift!['opening_cash'] as num?)?.toStringAsFixed(0) ?? "0"}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Action buttons
                              Row(
                                children: [
                                  if (_currentShift == null)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showOpenShiftDialog,
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                        label: const Text('Buka Shift'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4CAF50),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showCloseShiftDialog,
                                        icon: const Icon(Icons.stop_rounded, size: 18),
                                        label: const Text('Tutup Shift'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF6B35),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => Get.toNamed('/shift-history'),
                                    icon: const Icon(Icons.history_rounded, size: 16),
                                    label: const Text('Riwayat'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF00BCD4),
                                      side: const BorderSide(color: Color(0xFF00BCD4)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Lainnya (semua role) ──────────────────────────
                Builder(builder: (ctx) {
                  final otherIsDark = Theme.of(ctx).brightness == Brightness.dark;
                  return _sectionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Lainnya',
                  color: Colors.red.shade600,
                  child: Column(
                    children: [
                      if (user?.role == 'owner' || user?.role == 'manager') ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: otherIsDark
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.swap_horiz_rounded,
                                color: Colors.orange.shade700, size: 20),
                          ),
                          title: Text('Ganti Cabang',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: otherIsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
                          subtitle: Text(
                            _authService.selectedBranch?.name ?? '-',
                            style: TextStyle(
                                fontSize: 11,
                                color: otherIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: otherIsDark ? const Color(0xFF5A5F7A) : Colors.grey.shade400),
                          onTap: () => Get.offAllNamed('/branch-selection'),
                        ),
                        _divider(),
                      ],
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: otherIsDark
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.logout_rounded,
                              color: Colors.red.shade600, size: 20),
                        ),
                        title: const Text('Keluar',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                        subtitle: Text('Logout dari akun ini',
                            style: TextStyle(
                                fontSize: 11,
                                color: otherIsDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500)),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: otherIsDark ? const Color(0xFF5A5F7A) : Colors.grey.shade400),
                        onTap: _confirmLogout,
                      ),
                    ],
                  ),
                  );
                }),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shift methods ──────────────────────────────────────────────────────────
  Future<void> _loadCurrentShift() async {
    if (_shiftSvc == null) return;
    setState(() => _isLoadingShift = true);
    try {
      await _shiftSvc!.refresh();
      if (mounted) setState(() { _currentShift = _shiftSvc!.currentShift.value; _isLoadingShift = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingShift = false);
    }
  }

  void _showOpenShiftDialog() {
    final cashCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buka Shift', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan modal kas awal shift:',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Modal Awal (Rp)',
                prefixIcon: const Icon(Icons.payments_rounded, color: Color(0xFF4CAF50)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final cash = double.tryParse(cashCtrl.text) ?? 0;
              Get.back();
              try {
                await _shiftSvc!.openShift(cash);
                Get.snackbar('Shift Dibuka', 'Shift berhasil dibuka dengan modal Rp ${cash.toStringAsFixed(0)}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF4CAF50),
                    colorText: Colors.white);
                _loadCurrentShift();
              } catch (e) {
                Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.TOP, backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Buka Shift'),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog() {
    final cashCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan jumlah kas akhir shift:',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Kas Akhir (Rp)',
                prefixIcon: const Icon(Icons.payments_rounded, color: Color(0xFFFF6B35)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final cash = double.tryParse(cashCtrl.text) ?? 0;
              Get.back();
              try {
                final result = await _shiftSvc!.closeShift(
                    closingCash: cash,
                    notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null);
                final variance = (result?['cash_variance'] as num?)?.toDouble() ?? 0;
                final varStr = variance >= 0 ? '+Rp ${variance.toStringAsFixed(0)}' : '-Rp ${(-variance).toStringAsFixed(0)}';
                Get.snackbar('Shift Ditutup',
                    'Selisih kas: $varStr',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: variance >= 0 ? const Color(0xFF4CAF50) : Colors.orange,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 4));
                _loadCurrentShift();
              } catch (e) {
                Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.TOP, backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tutup Shift'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1D26) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2A2D3E) : Colors.grey.shade100;
    final titleColor = isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: titleColor)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? const Color(0xFF5A5F7A) : Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
        ],
      ),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(height: 1, color: isDark ? const Color(0xFF2A2D3E) : Colors.grey.shade100);
  }

  Widget _langChip({
    required String label,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2196F3).withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF242838) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : (isDark ? const Color(0xFF2E3147) : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : (isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600))),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle_rounded,
                    size: 12, color: Color(0xFF2196F3)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _themePreviewChip({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: textColor)),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle_rounded,
                    size: 12, color: Color(0xFF9C27B0)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade700;
    final fillColor = isDark ? const Color(0xFF242838) : const Color(0xFFF9F9F9);
    final borderColor = isDark ? const Color(0xFF2E3147) : Colors.grey.shade200;
    final textColor = isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26);
    final hintColor = isDark ? const Color(0xFF5A5F7A) : Colors.grey.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelColor)),
            if (required)
              const Text(' *',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:   controller,
          maxLines:     maxLines,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 13, color: textColor),
          decoration: InputDecoration(
            hintText:    hint,
            hintStyle:   TextStyle(color: hintColor, fontSize: 12),
            prefixIcon:  Icon(icon, size: 18, color: const Color(0xFFFF6B35)),
            filled:      true,
            fillColor:   fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 12, vertical: maxLines > 1 ? 12 : 0),
          ),
        ),
      ],
    );
  }

  String _roleLabel(String role) {
    const map = {
      'owner': 'Pemilik',
      'admin': 'Admin',
      'cashier': 'Kasir',
      'manager': 'Manajer',
    };
    return map[role] ?? role;
  }

  // ── Bluetooth Printer methods ──────────────────────────────────────────────

  Future<void> _scanAndSelectPrinter(BluetoothPrinterService btService) async {
    setState(() => _isScanningPrinter = true);
    final devices = await btService.getPairedDevices();
    setState(() => _isScanningPrinter = false);

    if (devices.isEmpty) {
      Get.snackbar(
        'Tidak Ada Printer',
        'Tidak ada perangkat Bluetooth yang di-pair. Pair printer di Pengaturan Bluetooth HP terlebih dahulu.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    if (!mounted) return;

    // Tampil dialog pilih printer
    final selected = await showDialog<BluetoothInfo>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Pilih Printer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: devices.length,
              separatorBuilder: (_, __) => Divider(height: 1,
                  color: isDark ? const Color(0xFF2A2D3E) : Colors.grey.shade200),
              itemBuilder: (ctx, i) {
                final device = devices[i];
                return ListTile(
                  leading: const Icon(Icons.print_rounded, color: Color(0xFF7C3AED)),
                  title: Text(device.name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
                  subtitle: Text(device.macAdress,
                      style: TextStyle(fontSize: 11,
                          color: isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600)),
                  onTap: () => Navigator.pop(ctx, device),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;

    await btService.savePrinter(selected.name, selected.macAdress);
    Get.snackbar(
      'Printer Disimpan',
      '${selected.name} berhasil dipilih sebagai printer.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF7C3AED),
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
    );
  }

  Future<void> _doTestPrint(BluetoothPrinterService btService) async {
    setState(() => _isTestPrinting = true);
    final success = await btService.printTest();
    setState(() => _isTestPrinting = false);
    Get.snackbar(
      success ? 'Test Print Berhasil' : 'Test Print Gagal',
      success ? 'Struk test berhasil dicetak.' : 'Gagal terhubung ke printer. Pastikan printer menyala dan dalam jangkauan.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red.shade600,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
      icon: Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
    );
  }

  void _clearPrinter(BluetoothPrinterService btService) {
    Get.dialog(AlertDialog(
      title: const Text('Hapus Printer'),
      content: Text('Hapus printer ${btService.savedPrinterName.value}?'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Get.back();
            await btService.clearPrinter();
          },
          child: const Text('Hapus', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── Backup methods ─────────────────────────────────────────────────────────

  Future<void> _doBackup() async {
    setState(() {
      _isBackingUp = true;
      _lastBackupPath = null;
    });
    try {
      final backupService = Get.find<BackupService>();
      final path = await backupService.downloadBackup();
      setState(() {
        _isBackingUp = false;
        _lastBackupPath = path;
      });
      final filename = path.split('/').last;
      Get.snackbar(
        'Backup Berhasil',
        'File tersimpan: $filename\nTap "Bagikan File Backup" untuk berbagi.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );
    } catch (e) {
      setState(() => _isBackingUp = false);
      Get.snackbar(
        'Backup Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
    }
  }

  Future<void> _shareBackup(String path) async {
    final filename = path.split('/').last;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/gzip', name: filename)],
      subject: 'Backup Database POS - $filename',
      text: 'File backup database POS: $filename',
    );
  }

  Future<void> _doRestore() async {
    // Warning dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                'Restore Database',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                ),
              ),
            ],
          ),
          content: Text(
            'PERHATIAN: Restore akan menghapus SEMUA data saat ini dan menggantinya dengan data dari file backup.\n\nPastikan Anda memilih file backup yang benar.\n\nLanjutkan?',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Restore', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    // File picker — pilih file .gz
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gz'],
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;

    setState(() => _isRestoring = true);
    try {
      final backupService = Get.find<BackupService>();
      await backupService.restoreBackup(filePath);
      setState(() => _isRestoring = false);
      Get.snackbar(
        'Restore Berhasil',
        'Database berhasil di-restore dari backup.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );
    } catch (e) {
      setState(() => _isRestoring = false);
      Get.snackbar(
        'Restore Gagal',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
    }
  }

  void _confirmLogout() {
    Get.dialog(
      Builder(builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Keluar',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26))),
          content: Text('Yakin ingin keluar dari akun ini?',
              style: TextStyle(color: isDark ? const Color(0xFF8B8FA8) : null)),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text('Batal',
                  style: TextStyle(
                      color: isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await Get.find<AuthService>().logout();
                Get.offAllNamed('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      }),
    );
  }
}
