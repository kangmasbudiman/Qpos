import 'package:get/get.dart';
import '../../data/models/branch_model.dart';
import '../../data/models/category_model.dart';
import '../../services/category/category_service.dart';

class CategoryController extends GetxController {
  final CategoryService _categoryService = Get.find<CategoryService>();

  // Branch yang sedang dipilih untuk filter
  final Rx<Branch?> selectedBranch = Rx<Branch?>(null);

  // State
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  // List reaktif yang dipakai Obx di UI
  final RxList<Category> displayedCategories = <Category>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Setiap kali categories di service berubah, atau search/branch berubah → rebuild list
    ever(_categoryService.categories, (_) => _rebuildList());
    ever(selectedBranch, (_) => _rebuildList());
    ever(searchQuery, (_) => _rebuildList());
    _rebuildList();
  }

  void _rebuildList() {
    // _categoryService.categories berisi SEMUA kategori (tanpa filter branch),
    // sehingga filter branch diterapkan di sini secara in-memory.
    List<Category> list = List<Category>.from(_categoryService.categories);

    // Filter branch: merchant-level (branch_id NULL) selalu tampil,
    // branch-specific hanya tampil jika cocok dengan branch yang dipilih.
    final branch = selectedBranch.value;
    if (branch != null) {
      list = list
          .where((c) => c.branchId == null || c.branchId == branch.id)
          .toList();
    }

    // Filter pencarian
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }

    displayedCategories.value = list;
  }

  List<Category> get merchantCategories =>
      _categoryService.merchantCategories;

  /// Pilih branch untuk difilter (langsung reload dari DB)
  void selectBranch(Branch? branch) {
    selectedBranch.value = branch;
    reload();
  }

  /// Reload semua kategori dari DB (filter branch diterapkan in-memory di _rebuildList)
  Future<void> reload() async {
    isLoading.value = true;
    await _categoryService.loadCategories();
    isLoading.value = false;
    _rebuildList();
  }

  void setSearch(String query) => searchQuery.value = query;

  /// Tambah kategori baru
  Future<bool> addCategory({
    required String name,
    String? description,
    int? branchId,
    String? branchName,
    bool isActive = true,
  }) async {
    isLoading.value = true;
    final category = Category(
      id: 0,
      name: name,
      description: description,
      branchId: branchId,
      branchName: branchName,
      isActive: isActive,
    );
    final result = await _categoryService.addCategory(category);
    isLoading.value = false;
    return result;
  }

  /// Update kategori
  Future<bool> updateCategory(Category category) async {
    isLoading.value = true;
    final result = await _categoryService.updateCategory(category);
    isLoading.value = false;
    return result;
  }

  /// Hapus kategori (soft delete)
  Future<bool> deleteCategory(int categoryId) async {
    isLoading.value = true;
    final result = await _categoryService.deleteCategory(categoryId);
    isLoading.value = false;
    return result;
  }
}
