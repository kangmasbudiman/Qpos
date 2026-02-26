import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/category_model.dart';
import '../../services/auth/auth_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/category_controller.dart';

// ── Warna tema (sama dengan dashboard & sync screen) ────────────────────────
const _kPrimary = Color(0xFF1E2235);
const _kAccent  = Color(0xFFFF6B35);
const _kBg      = Color(0xFFF5F6FA);

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl     = Get.find<CategoryController>();
    final authCtrl = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Hero SliverAppBar ─────────────────────────────────────
          _buildAppBar(context, ctrl, authCtrl),

          // ── Konten ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter branch
                _BranchFilterBar(ctrl: ctrl, authCtrl: authCtrl),

                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _SearchBar(ctrl: ctrl),
                ),
              ],
            ),
          ),

          // ── Daftar kategori ───────────────────────────────────────
          _CategoryList(ctrl: ctrl, authCtrl: authCtrl),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon:  const Icon(Icons.add_rounded),
        label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => CategoryFormSheet.show(context,
            ctrl: ctrl, authCtrl: authCtrl),
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    CategoryController ctrl,
    AuthController authCtrl,
  ) {
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.cloud_download_rounded),
                tooltip: 'Ambil data dari server',
                onPressed: () async {
                  final auth = Get.find<AuthService>();
                  final ok = await auth.refreshCategoriesFromServer();
                  Get.snackbar(
                    ok ? 'Berhasil' : 'Gagal',
                    ok
                        ? 'Kategori berhasil diperbarui dari server'
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
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
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
                    child: const Icon(
                        Icons.category_rounded, color: _kAccent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Kategori',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        Obx(() {
                          final total = ctrl.displayedCategories.length;
                          final branch = ctrl.selectedBranch.value;
                          return Text(
                            branch == null
                                ? '$total kategori (semua branch)'
                                : '$total kategori · ${branch.name}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
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
  final CategoryController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        onChanged: ctrl.setSearch,
        decoration: InputDecoration(
          hintText:     'Cari kategori...',
          hintStyle:    TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon:   Icon(Icons.search_rounded,
              color: Colors.grey.shade400, size: 20),
          border:       InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Branch Filter Bar ────────────────────────────────────────────────────────

class _BranchFilterBar extends StatelessWidget {
  const _BranchFilterBar({required this.ctrl, required this.authCtrl});
  final CategoryController ctrl;
  final AuthController     authCtrl;

  @override
  Widget build(BuildContext context) {
    final branches = authCtrl.branches;
    if (branches.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Obx(() => _BranchChip(
                label:    'Semua',
                selected: ctrl.selectedBranch.value == null,
                onTap:    () => ctrl.selectBranch(null),
              )),
          ...branches.map(
            (b) => Obx(() => _BranchChip(
                  label:    b.name,
                  selected: ctrl.selectedBranch.value?.id == b.id,
                  onTap:    () => ctrl.selectBranch(b),
                )),
          ),
        ],
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String        label;
  final bool          selected;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color:        selected ? _kAccent : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(
              color: selected ? _kAccent : Colors.grey.shade300,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:      _kAccent.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset:     const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize:   13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color:      selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category List (Sliver) ───────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.ctrl, required this.authCtrl});
  final CategoryController ctrl;
  final AuthController     authCtrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = ctrl.displayedCategories.toList();

      if (ctrl.isLoading.value && list.isEmpty) {
        return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: _kAccent)),
        );
      }

      if (list.isEmpty) {
        return SliverFillRemaining(
          child: _EmptyState(
            branchName: ctrl.selectedBranch.value?.name,
            onAdd: () => CategoryFormSheet.show(context,
                ctrl: ctrl, authCtrl: authCtrl),
          ),
        );
      }

      // Group: merchant-level dulu, lalu branch-specific
      final merchantCats = list.where((c) => c.isMerchantLevel).toList();
      final branchCats   = list.where((c) => !c.isMerchantLevel).toList();

      final items = <Widget>[];

      if (merchantCats.isNotEmpty) {
        items.add(_GroupHeader(
          icon:  Icons.store_rounded,
          label: 'Berlaku Semua Branch',
          count: merchantCats.length,
          color: const Color(0xFF2196F3),
        ));
        items.addAll(merchantCats.map((c) => _CategoryCard(
              category: c, ctrl: ctrl, authCtrl: authCtrl, context: context)));
      }

      if (branchCats.isNotEmpty) {
        items.add(_GroupHeader(
          icon:  Icons.location_on_rounded,
          label: ctrl.selectedBranch.value != null
              ? ctrl.selectedBranch.value!.name
              : 'Spesifik Branch',
          count: branchCats.length,
          color: const Color(0xFF4CAF50),
        ));
        items.addAll(branchCats.map((c) => _CategoryCard(
              category: c, ctrl: ctrl, authCtrl: authCtrl, context: context)));
      }

      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => items[i],
            childCount: items.length,
          ),
        ),
      );
    });
  }
}

// ── Group Header ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final int      count;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:  color.withValues(alpha: 0.12),
              shape:  BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.ctrl,
    required this.authCtrl,
    required this.context,
  });
  final Category           category;
  final CategoryController ctrl;
  final AuthController     authCtrl;
  final BuildContext       context;

  @override
  Widget build(BuildContext _) {
    final isMerchant = category.isMerchantLevel;
    final accent     = isMerchant
        ? const Color(0xFF2196F3)
        : const Color(0xFF4CAF50);

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
          onTap: () => CategoryFormSheet.show(
            context,
            ctrl:     ctrl,
            authCtrl: authCtrl,
            existing: category,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Ikon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color:  accent.withValues(alpha: 0.1),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: accent.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Icon(Icons.category_rounded,
                      color: accent, size: 22),
                ),
                const SizedBox(width: 14),

                // Teks
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   15,
                            color:      _kPrimary),
                      ),
                      if (category.description != null &&
                          category.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          category.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color:    Colors.grey.shade500),
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Badge branch
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isMerchant
                                  ? Icons.store_rounded
                                  : Icons.location_on_rounded,
                              size:  11,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isMerchant
                                  ? 'Semua Branch'
                                  : (category.branchName ??
                                      'Branch #${category.branchId}'),
                              style: TextStyle(
                                  fontSize:   11,
                                  color:      accent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
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
                  onSelected: (action) => _onAction(context, action),
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

  void _onAction(BuildContext ctx, String action) {
    if (action == 'edit') {
      CategoryFormSheet.show(
        context,
        ctrl:     ctrl,
        authCtrl: authCtrl,
        existing: category,
      );
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
            const Text('Hapus Kategori',
                style: TextStyle(fontSize: 16)),
          ]),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: Colors.black87, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Hapus kategori '),
                TextSpan(
                  text: '"${category.name}"',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                    text:
                        '?\n\nKategori yang dihapus tidak dapat dipulihkan.'),
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
        if (confirm == true) ctrl.deleteCategory(category.id);
      });
    }
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, this.branchName});
  final VoidCallback onAdd;
  final String?      branchName;

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
              child: const Icon(Icons.category_outlined,
                  size: 42, color: _kAccent),
            ),
            const SizedBox(height: 20),
            Text(
              branchName != null
                  ? 'Belum ada kategori\ndi branch "$branchName"'
                  : 'Belum ada kategori',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      _kPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah kategori baru untuk mengorganisir produk',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
              label:    const Text('Tambah Kategori',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form Bottom Sheet ────────────────────────────────────────────────────────

class CategoryFormSheet {
  static void show(
    BuildContext context, {
    required CategoryController ctrl,
    required AuthController authCtrl,
    Category? existing,
  }) {
    int?   formBranchId  = existing?.branchId;
    bool   formIsActive  = existing?.isActive ?? true;
    final  nameCtrl      = TextEditingController(text: existing?.name ?? '');
    final  descCtrl      = TextEditingController(
        text: existing?.description ?? '');
    final  formKey       = GlobalKey<FormState>();
    final  branches      = authCtrl.branches;

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
                          color:  _kAccent.withValues(alpha: 0.1),
                          shape:  BoxShape.circle,
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
                            ? 'Tambah Kategori'
                            : 'Edit Kategori',
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

                  // ── Pilih Branch ──────────────────────────────
                  _FieldLabel(
                      icon: Icons.location_on_outlined,
                      label: 'Branch (opsional)'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<int?>(
                      value:      formBranchId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border:         InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Row(children: [
                            Icon(Icons.store_rounded,
                                size: 16,
                                color: Colors.blue.shade400),
                            const SizedBox(width: 8),
                            const Text('Semua Branch (Merchant Level)'),
                          ]),
                        ),
                        ...branches.map((b) => DropdownMenuItem<int?>(
                              value: b.id,
                              child: Row(children: [
                                Icon(Icons.location_on_rounded,
                                    size: 16,
                                    color: Colors.green.shade400),
                                const SizedBox(width: 8),
                                Text(b.displayName),
                              ]),
                            )),
                      ],
                      onChanged: (val) =>
                          setLocal(() => formBranchId = val),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Nama ─────────────────────────────────────
                  _FieldLabel(
                      icon: Icons.label_outline_rounded,
                      label: 'Nama Kategori'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller:          nameCtrl,
                    textCapitalization:  TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText:     'Contoh: Minuman, Makanan...',
                      hintStyle:    TextStyle(color: Colors.grey.shade400),
                      border:       OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   const BorderSide(color: _kAccent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Nama kategori wajib diisi'
                            : null,
                  ),

                  const SizedBox(height: 18),

                  // ── Deskripsi ─────────────────────────────────
                  _FieldLabel(
                      icon: Icons.notes_rounded,
                      label: 'Deskripsi (opsional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descCtrl,
                    maxLines:   3,
                    decoration: InputDecoration(
                      hintText:  'Deskripsi singkat kategori...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border:    OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   const BorderSide(color: _kAccent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Toggle Aktif ──────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color:        formIsActive
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(
                        color: formIsActive
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      title: Text(
                        formIsActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: formIsActive
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      subtitle: Text(
                        formIsActive
                            ? 'Kategori ditampilkan di POS'
                            : 'Kategori disembunyikan dari POS',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500),
                      ),
                      value:       formIsActive,
                      activeColor: Colors.green,
                      onChanged: (v) => setLocal(() => formIsActive = v),
                    ),
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

                                final branchName = formBranchId != null
                                    ? branches
                                        .firstWhereOrNull(
                                            (b) => b.id == formBranchId)
                                        ?.name
                                    : null;

                                bool ok;
                                if (existing == null) {
                                  ok = await ctrl.addCategory(
                                    name:        nameCtrl.text.trim(),
                                    description: descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                    branchId:    formBranchId,
                                    branchName:  branchName,
                                    isActive:    formIsActive,
                                  );
                                } else {
                                  ok = await ctrl.updateCategory(
                                    existing.copyWith(
                                      name:        nameCtrl.text.trim(),
                                      description: descCtrl.text.trim().isEmpty
                                          ? null
                                          : descCtrl.text.trim(),
                                      branchId:    formBranchId,
                                      branchName:  branchName,
                                      isActive:    formIsActive,
                                    ),
                                  );
                                }

                                if (ok) {
                                  // Simpan nama sebelum di-clear
                                  final isAdd        = existing == null;
                                  final savedName    = nameCtrl.text.trim();

                                  // Clear semua field
                                  nameCtrl.clear();
                                  descCtrl.clear();
                                  formKey.currentState!.reset();

                                  // Tutup bottom sheet
                                  Get.back();

                                  // Notifikasi sukses
                                  Get.snackbar(
                                    isAdd
                                        ? 'Kategori Ditambahkan'
                                        : 'Kategori Diperbarui',
                                    '"$savedName" berhasil ${isAdd ? 'disimpan' : 'diperbarui'}',
                                    snackPosition:   SnackPosition.BOTTOM,
                                    backgroundColor: const Color(0xFF4CAF50),
                                    colorText:       Colors.white,
                                    margin:          const EdgeInsets.all(12),
                                    duration:        const Duration(seconds: 3),
                                    icon: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white),
                                    borderRadius: 12,
                                  );
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width:  22, height: 22,
                                child:  CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                existing == null ? 'Simpan Kategori' : 'Update Kategori',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
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

// ── Field Label helper ───────────────────────────────────────────────────────

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
