import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/supplier_model.dart';
import '../controllers/supplier_controller.dart';

// ── Warna tema (sama dengan screen lain) ────────────────────────────────────
const _kPrimary  = Color(0xFF1E2235);
const _kAccent   = Color(0xFF7C3AED); // ungu — identitas supplier
const _kBg       = Color(0xFFF5F6FA);

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SupplierController>();

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ctrl),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _SearchBar(ctrl: ctrl),
            ),
          ),

          _SupplierList(ctrl: ctrl),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon:  const Icon(Icons.add_rounded),
        label: const Text('Tambah',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => SupplierFormSheet.show(context, ctrl: ctrl),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, SupplierController ctrl) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      actions: [
        Obx(() => ctrl.isLoading.value
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.cloud_download_rounded),
                tooltip: 'Ambil data dari server',
                onPressed: () async {
                  final ok = await ctrl.fetchFromServer();
                  Get.snackbar(
                    ok ? 'Berhasil' : 'Gagal',
                    ok
                        ? 'Data supplier diperbarui'
                        : 'Tidak dapat terhubung ke server',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor:
                        ok ? const Color(0xFF4CAF50) : Colors.orange.shade700,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(12),
                    duration: const Duration(seconds: 3),
                    icon: Icon(
                      ok ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
                      color: Colors.white,
                    ),
                  );
                },
              )),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 54, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color:  _kAccent.withValues(alpha: 0.15),
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: _kAccent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.business_rounded,
                        color: _kAccent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Supplier',
                          style: TextStyle(
                              color:      Colors.white,
                              fontSize:   22,
                              fontWeight: FontWeight.bold),
                        ),
                        Obx(() {
                          final total = ctrl.displayedSuppliers.length;
                          return Text(
                            '$total supplier terdaftar',
                            style: TextStyle(
                                color:   Colors.white.withValues(alpha: 0.7),
                                fontSize: 12),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.ctrl});
  final SupplierController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged:  ctrl.setSearch,
        decoration: InputDecoration(
          hintText:  'Cari supplier...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.grey.shade400, size: 20),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Supplier List ────────────────────────────────────────────────────────────

class _SupplierList extends StatelessWidget {
  const _SupplierList({required this.ctrl});
  final SupplierController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = ctrl.displayedSuppliers.toList();

      if (ctrl.isLoading.value && list.isEmpty) {
        return const SliverFillRemaining(
          child: Center(
              child: CircularProgressIndicator(color: _kAccent)),
        );
      }

      if (list.isEmpty) {
        return SliverFillRemaining(
          child: _EmptyState(
            onAdd: () => SupplierFormSheet.show(context, ctrl: ctrl),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _SupplierCard(
                supplier: list[i], ctrl: ctrl, context: context),
            childCount: list.length,
          ),
        ),
      );
    });
  }
}

// ── Supplier Card ─────────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.ctrl,
    required this.context,
  });
  final Supplier           supplier;
  final SupplierController ctrl;
  final BuildContext       context;

  @override
  Widget build(BuildContext _) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => SupplierFormSheet.show(context,
              ctrl: ctrl, existing: supplier),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar inisial
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color:  _kAccent.withValues(alpha: 0.1),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: _kAccent.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      supplier.name.isNotEmpty
                          ? supplier.name[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                          color:      _kAccent,
                          fontWeight: FontWeight.bold,
                          fontSize:   18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   15,
                            color:      _kPrimary),
                      ),
                      if (supplier.companyName?.isNotEmpty == true &&
                          supplier.companyName != supplier.name) ...[
                        const SizedBox(height: 2),
                        Text(
                          supplier.name,
                          style: TextStyle(
                              fontSize: 12,
                              color:    Colors.grey.shade500),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (supplier.phone?.isNotEmpty == true) ...[
                            _infoChip(Icons.phone_outlined,
                                supplier.phone!),
                            const SizedBox(width: 8),
                          ],
                          if (supplier.email?.isNotEmpty == true)
                            _infoChip(Icons.email_outlined,
                                supplier.email!),
                        ],
                      ),
                    ],
                  ),
                ),

                // Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) =>
                      _onAction(context, action),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: _kPrimary),
                        const SizedBox(width: 10),
                        const Text('Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 10),
                        const Text('Hapus',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade400),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _onAction(BuildContext ctx, String action) {
    if (action == 'edit') {
      SupplierFormSheet.show(context, ctrl: ctrl, existing: supplier);
    } else if (action == 'delete') {
      Get.dialog<bool>(
        AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Supplier',
                style: TextStyle(fontSize: 16)),
          ]),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: Colors.black87, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Hapus supplier '),
                TextSpan(
                  text: '"${supplier.displayName}"',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                    text: '?\n\nData yang dihapus tidak dapat dipulihkan.'),
              ],
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('Batal',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
              onPressed: () => Get.back(result: true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      ).then((confirm) {
        if (confirm == true) {
          ctrl.deleteSupplier(supplier.id, supplier.displayName);
        }
      });
    }
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color:  _kAccent.withValues(alpha: 0.08),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: _kAccent.withValues(alpha: 0.2), width: 2),
              ),
              child: const Icon(Icons.business_outlined,
                  size: 42, color: _kAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada supplier',
              style: TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      _kPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah supplier untuk digunakan pada Purchase Order',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon:     const Icon(Icons.add_rounded),
              label:    const Text('Tambah Supplier',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form Bottom Sheet ─────────────────────────────────────────────────────────

class SupplierFormSheet {
  static void show(
    BuildContext context, {
    required SupplierController ctrl,
    Supplier? existing,
  }) {
    final nameCtrl    = TextEditingController(text: existing?.name        ?? '');
    final companyCtrl = TextEditingController(text: existing?.companyName ?? '');
    final phoneCtrl   = TextEditingController(text: existing?.phone       ?? '');
    final emailCtrl   = TextEditingController(text: existing?.email       ?? '');
    final addressCtrl = TextEditingController(text: existing?.address     ?? '');
    final formKey     = GlobalKey<FormState>();

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      StatefulBuilder(builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle drag
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color:        Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          existing == null
                              ? Icons.add_rounded
                              : Icons.edit_rounded,
                          color: _kAccent, size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        existing == null
                            ? 'Tambah Supplier'
                            : 'Edit Supplier',
                        style: const TextStyle(
                            fontSize:   18,
                            fontWeight: FontWeight.bold,
                            color:      _kPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: Get.back,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Nama Supplier ─────────────────────────────
                  _FieldLabel(
                      icon: Icons.person_outline_rounded,
                      label: 'Nama Supplier'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco(
                        'Nama supplier (PIC / kontak)'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Nama supplier wajib diisi'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Nama Perusahaan ───────────────────────────
                  _FieldLabel(
                      icon: Icons.business_rounded,
                      label: 'Nama Perusahaan (opsional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: companyCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco('PT / CV / UD ...'),
                  ),
                  const SizedBox(height: 16),

                  // ── Telepon ───────────────────────────────────
                  _FieldLabel(
                      icon: Icons.phone_outlined,
                      label: 'Telepon (opsional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller:  phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration:  _inputDeco('08xxxxxxxxxx'),
                  ),
                  const SizedBox(height: 16),

                  // ── Email ─────────────────────────────────────
                  _FieldLabel(
                      icon: Icons.email_outlined,
                      label: 'Email (opsional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller:  emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration:  _inputDeco('contoh@email.com'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final emailRegex =
                          RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      return emailRegex.hasMatch(v.trim())
                          ? null
                          : 'Format email tidak valid';
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Alamat ────────────────────────────────────
                  _FieldLabel(
                      icon: Icons.location_on_outlined,
                      label: 'Alamat (opsional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines:   3,
                    decoration: _inputDeco('Jl. ...'),
                  ),
                  const SizedBox(height: 24),

                  // ── Tombol Simpan ─────────────────────────────
                  Obx(() {
                    final saving = ctrl.isLoading.value;
                    return SizedBox(
                      width:  double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saving
                              ? Colors.grey.shade300
                              : _kAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: saving ? 0 : 2,
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                bool ok;
                                final savedName =
                                    companyCtrl.text.trim().isNotEmpty
                                        ? companyCtrl.text.trim()
                                        : nameCtrl.text.trim();

                                if (existing == null) {
                                  ok = await ctrl.addSupplier(
                                    name:        nameCtrl.text.trim(),
                                    companyName: companyCtrl.text.trim().isEmpty
                                        ? null
                                        : companyCtrl.text.trim(),
                                    phone:   phoneCtrl.text.trim().isEmpty
                                        ? null
                                        : phoneCtrl.text.trim(),
                                    email:   emailCtrl.text.trim().isEmpty
                                        ? null
                                        : emailCtrl.text.trim(),
                                    address: addressCtrl.text.trim().isEmpty
                                        ? null
                                        : addressCtrl.text.trim(),
                                  );
                                } else {
                                  ok = await ctrl.updateSupplier(
                                    Supplier(
                                      id:          existing.id,
                                      merchantId:  existing.merchantId,
                                      name:        nameCtrl.text.trim(),
                                      companyName: companyCtrl.text.trim().isEmpty
                                          ? null
                                          : companyCtrl.text.trim(),
                                      phone:   phoneCtrl.text.trim().isEmpty
                                          ? null
                                          : phoneCtrl.text.trim(),
                                      email:   emailCtrl.text.trim().isEmpty
                                          ? null
                                          : emailCtrl.text.trim(),
                                      address: addressCtrl.text.trim().isEmpty
                                          ? null
                                          : addressCtrl.text.trim(),
                                      isActive: existing.isActive,
                                    ),
                                  );
                                }

                                if (ok) Get.back();
                              },
                        child: saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                existing == null
                                    ? 'Simpan Supplier'
                                    : 'Update Supplier',
                                style: const TextStyle(
                                    fontSize:   15,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

InputDecoration _inputDeco(String hint) {
  return InputDecoration(
    hintText:  hint,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    border:    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:   BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:   const BorderSide(color: _kAccent),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:   const BorderSide(color: Colors.red),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _kPrimary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize:   13,
              color:      _kPrimary),
        ),
      ],
    );
  }
}
