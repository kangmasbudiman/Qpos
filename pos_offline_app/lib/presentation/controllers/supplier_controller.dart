import 'package:get/get.dart';

import '../../data/models/supplier_model.dart';
import '../../services/supplier/supplier_service.dart';

class SupplierController extends GetxController {
  final SupplierService _svc = Get.find<SupplierService>();

  final RxList<Supplier> displayedSuppliers = <Supplier>[].obs;
  final RxString searchQuery = ''.obs;
  RxBool get isLoading => _svc.isLoading;

  @override
  void onInit() {
    super.onInit();
    // Rebuild list setiap kali suppliers di service atau search query berubah
    ever(_svc.suppliers as RxList<Supplier>, (_) => _rebuildList());
    ever(searchQuery, (_) => _rebuildList());
    _rebuildList();
  }

  void _rebuildList() {
    final q    = searchQuery.value.toLowerCase();
    final list = _svc.suppliers;

    if (q.isEmpty) {
      displayedSuppliers.value = List.from(list);
    } else {
      displayedSuppliers.value = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.companyName?.toLowerCase().contains(q) ?? false) ||
            (s.phone?.contains(q) ?? false) ||
            (s.email?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  void setSearch(String q) => searchQuery.value = q;

  Future<void> reload() => _svc.loadSuppliers();

  Future<bool> fetchFromServer() => _svc.fetchFromServer();

  Future<bool> addSupplier({
    required String name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
  }) =>
      _svc.addSupplier(
        name:        name,
        companyName: companyName,
        phone:       phone,
        email:       email,
        address:     address,
      );

  Future<bool> updateSupplier(Supplier supplier) =>
      _svc.updateSupplier(supplier);

  Future<bool> deleteSupplier(int id, String name) =>
      _svc.deleteSupplier(id, name);
}
