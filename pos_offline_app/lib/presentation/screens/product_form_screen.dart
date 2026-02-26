import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/category/category_service.dart';
import '../../services/inventory/inventory_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = tambah baru, non-null = edit
  const ProductFormScreen({Key? key, this.product}) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _svc      = Get.find<InventoryService>();
  final _picker   = ImagePicker();

  // CategoryService bisa saja belum diregistrasi di beberapa versi
  CategoryService? get _catSvc =>
      Get.isRegistered<CategoryService>() ? Get.find<CategoryService>() : null;

  bool get _isEdit => widget.product != null;
  bool _isLoading  = false;
  File? _imageFile; // gambar baru dipilih

  // State kategori
  int?             _selectedCategoryId;
  List<Category>   _categories = [];

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _descCtrl;
  String _unit = 'pcs';

  final _units = ['pcs', 'kg', 'gram', 'liter', 'ml', 'box', 'lusin', 'dus'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl     = TextEditingController(text: p?.name ?? '');
    _skuCtrl      = TextEditingController(text: p?.sku ?? '');
    _barcodeCtrl  = TextEditingController(text: p?.barcode ?? '');
    _priceCtrl    = TextEditingController(
        text: p != null ? p.price.toInt().toString() : '');
    _costCtrl     = TextEditingController(
        text: p != null ? p.cost.toInt().toString() : '');
    _stockCtrl    = TextEditingController(
        text: p != null ? '${p.localStock ?? 0}' : '0');
    _minStockCtrl = TextEditingController(
        text: p != null ? '${p.minStock}' : '0');
    _descCtrl            = TextEditingController(text: p?.description ?? '');
    _unit                = p?.unit ?? 'pcs';
    _selectedCategoryId  = p?.categoryId;

    // Muat daftar kategori
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final svc = _catSvc;
    if (svc == null) return;
    if (svc.categories.isEmpty) await svc.loadCategories();

    // Filter hanya kategori yang berlaku untuk branch aktif:
    // merchant-level (branchId == null) + kategori branch saat ini
    final activeBranchId =
        Get.find<AuthService>().selectedBranch?.id;

    if (mounted) {
      setState(() {
        _categories = svc.categories.where((c) {
          if (c.branchId == null) return true; // merchant-level, selalu tampil
          if (activeBranchId == null) return true; // belum pilih branch, tampil semua
          return c.branchId == activeBranchId;
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _skuCtrl, _barcodeCtrl, _priceCtrl,
      _costCtrl, _stockCtrl, _minStockCtrl, _descCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Pilih gambar ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Pilih Gambar',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFF2196F3)),
              ),
              title: const Text('Kamera'),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF9C27B0)),
              ),
              title: const Text('Galeri'),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imageFile != null ||
                (widget.product?.image != null))
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: Color(0xFFF44336)),
                ),
                title: const Text('Hapus Gambar',
                    style: TextStyle(color: Color(0xFFF44336))),
                onTap: () {
                  setState(() => _imageFile = null);
                  Get.back();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Simpan ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Gunakan path gambar baru jika dipilih, atau pertahankan lama
    final imagePath = _imageFile?.path ?? widget.product?.image;

    final product = Product(
      id:          widget.product?.id,
      merchantId:  widget.product?.merchantId,
      categoryId:  _selectedCategoryId,
      name:        _nameCtrl.text.trim(),
      sku:         _skuCtrl.text.trim(),
      barcode:     _barcodeCtrl.text.trim().isEmpty
                       ? null
                       : _barcodeCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
                       ? null
                       : _descCtrl.text.trim(),
      price:       double.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0,
      cost:        double.tryParse(_costCtrl.text.replaceAll('.', '')) ?? 0,
      unit:        _unit,
      minStock:    int.tryParse(_minStockCtrl.text) ?? 0,
      localStock:  int.tryParse(_stockCtrl.text) ?? 0,
      image:       imagePath,
      isActive:    true,
      isSynced:    false,
      createdAt:   widget.product?.createdAt ??
                       DateTime.now().toIso8601String(),
    );

    bool ok;
    if (_isEdit) {
      ok = await _svc.updateProduct(product);
    } else {
      ok = await _svc.addProduct(product);
    }

    setState(() => _isLoading = false);

    if (ok) {
      // Simpan nama sebelum di-clear untuk notifikasi
      final savedName = product.name;

      // Bersihkan semua field jika mode tambah baru
      if (!_isEdit) {
        _nameCtrl.clear();
        _skuCtrl.clear();
        _barcodeCtrl.clear();
        _priceCtrl.clear();
        _costCtrl.clear();
        _stockCtrl.text    = '0';
        _minStockCtrl.text = '0';
        _descCtrl.clear();
        setState(() {
          _unit               = 'pcs';
          _imageFile          = null;
          _selectedCategoryId = null;
        });
      }

      Get.snackbar(
        _isEdit ? 'Produk Diperbarui' : 'Produk Ditambahkan',
        '"$savedName" berhasil ${_isEdit ? 'diperbarui' : 'disimpan'}',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: const Color(0xFF4CAF50),
        colorText:       Colors.white,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        margin:          const EdgeInsets.all(12),
        borderRadius:    12,
        duration:        const Duration(seconds: 3),
      );
      Get.back();
    } else {
      Get.snackbar(
        'Gagal Menyimpan',
        _isEdit
            ? 'Produk tidak dapat diperbarui, coba lagi'
            : 'Produk tidak dapat disimpan, coba lagi',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
        icon: const Icon(Icons.error_rounded, color: Colors.white),
        margin:          const EdgeInsets.all(12),
        borderRadius:    12,
        duration:        const Duration(seconds: 4),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gambar produk
                          _buildImagePicker(),
                          const SizedBox(height: 24),

                          // Informasi dasar
                          _sectionLabel('Informasi Produk'),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _nameCtrl,
                            label: 'Nama Produk',
                            hint: 'Contoh: Kopi Arabika',
                            icon: Icons.label_rounded,
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _skuCtrl,
                                  label: 'SKU',
                                  hint: 'KP-001',
                                  icon: Icons.qr_code_rounded,
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildField(
                                  controller: _barcodeCtrl,
                                  label: 'Barcode',
                                  hint: '8991234567890',
                                  icon: Icons.barcode_reader,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _descCtrl,
                            label: 'Deskripsi',
                            hint: 'Deskripsi produk (opsional)',
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),

                          // Kategori
                          _sectionLabel('Kategori'),
                          const SizedBox(height: 12),
                          _buildCategorySelector(),
                          const SizedBox(height: 24),

                          // Harga
                          _sectionLabel('Harga'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _priceCtrl,
                                  label: 'Harga Jual',
                                  hint: '15000',
                                  icon: Icons.sell_rounded,
                                  prefix: 'Rp ',
                                  keyboardType: TextInputType.number,
                                  required: true,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildField(
                                  controller: _costCtrl,
                                  label: 'Harga Modal',
                                  hint: '10000',
                                  icon: Icons.shopping_bag_outlined,
                                  prefix: 'Rp ',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Stok
                          _sectionLabel('Stok & Satuan'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _stockCtrl,
                                  label: 'Stok Awal',
                                  hint: '0',
                                  icon: Icons.inventory_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildField(
                                  controller: _minStockCtrl,
                                  label: 'Min. Stok',
                                  hint: '5',
                                  icon: Icons.warning_amber_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildUnitSelector(),
                          const SizedBox(height: 32),

                          // Tombol simpan
                          _buildSaveButton(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      size: 16, color: Color(0xFF1A1D26)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEdit ? 'Edit Produk' : 'Tambah Produk',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D26),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _isEdit
                          ? 'Ubah informasi produk'
                          : 'Isi data produk baru',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    final hasExistingImage =
        widget.product?.image != null && _imageFile == null;
    final hasNewImage = _imageFile != null;

    return GestureDetector(
      onTap: _showImageOptions,
      child: Center(
        child: Column(
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: hasNewImage || hasExistingImage
                      ? const Color(0xFFFF6B35).withValues(alpha: 0.3)
                      : const Color(0xFFEEEEEE),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: hasNewImage
                    ? Image.file(_imageFile!,
                        fit: BoxFit.cover,
                        width: 120, height: 120)
                    : hasExistingImage
                        ? _buildExistingImage(widget.product!.image!)
                        : _buildDefaultProductIcon(),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      size: 13, color: Color(0xFFFF6B35)),
                  const SizedBox(width: 5),
                  Text(
                    hasNewImage || hasExistingImage
                        ? 'Ganti Gambar'
                        : 'Tambah Gambar',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultProductIcon() {
    return Container(
      color: const Color(0xFFF7F8FA),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFFFF6B35),
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap untuk\npilih gambar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingImage(String imagePath) {
    // Jika path adalah URL
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: 120, height: 120,
        errorBuilder: (_, __, ___) => _buildDefaultProductIcon(),
      );
    }
    // Jika path file lokal
    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(file,
          fit: BoxFit.cover, width: 120, height: 120);
    }
    return _buildDefaultProductIcon();
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4, height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D26),
          ),
        ),
      ],
    );
  }

  // ── Field ─────────────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefix,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? '$label tidak boleh kosong'
                : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
              color: Colors.grey[500], fontSize: 13),
          hintStyle:
              TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon,
              size: 18, color: const Color(0xFFFF6B35)),
          prefix: prefix != null
              ? Text(prefix,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1D26),
                      fontSize: 13))
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFFF6B35), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFF44336), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFF44336), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 14 : 0),
        ),
      ),
    );
  }

  // ── Category selector ─────────────────────────────────────────────────────

  Widget _buildCategorySelector() {
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.category_rounded,
                size: 18, color: Color(0xFFFF6B35)),
            const SizedBox(width: 12),
            Text(
              'Tidak ada kategori tersedia',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selectedCategoryId != null
              ? const Color(0xFFFF6B35).withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedCategoryId,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.category_rounded,
              size: 18, color: Color(0xFFFF6B35)),
          labelText: 'Kategori',
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFFF6B35), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
        hint: Text('Pilih kategori (opsional)',
            style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFFF6B35)),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text('— Tanpa Kategori —',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          ..._categories.map((cat) => DropdownMenuItem<int>(
                value: cat.id,
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: cat.branchId == null
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (cat.branchName != null)
                      Text(
                        cat.branchName!,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[400]),
                      ),
                  ],
                ),
              )),
        ],
        onChanged: (val) => setState(() => _selectedCategoryId = val),
      ),
    );
  }

  // ── Unit selector ─────────────────────────────────────────────────────────

  Widget _buildUnitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Satuan',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _units.map((u) {
            final sel = _unit == u;
            return GestureDetector(
              onTap: () => setState(() => _unit = u),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFFFF6B35)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFFDDDDDD),
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  u,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Tombol simpan ─────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEdit
                        ? Icons.save_rounded
                        : Icons.add_circle_rounded,
                    color: Colors.white, size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEdit ? 'Simpan Perubahan' : 'Tambah Produk',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
