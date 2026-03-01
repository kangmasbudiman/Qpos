import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';
import '../../core/utils/connectivity_utils.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/sync_queue_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../services/database/database_helper.dart';
import '../../services/print/thermal_printer_service.dart';
import '../../services/print/bluetooth_printer_service.dart';
import '../../services/sync/sync_service.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;
  bool discountIsPercent; // true = persen, false = nominal

  CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0.0,
    this.discountIsPercent = false,
  });

  double get subtotal {
    final gross = product.price * quantity;
    final disc = discountIsPercent ? gross * (discount / 100) : discount;
    return gross - disc;
  }

  double get totalDiscount {
    final gross = product.price * quantity;
    return discountIsPercent ? gross * (discount / 100) : discount;
  }

  Map<String, dynamic> toJson() => {
    'product_id': product.id,
    'product_name': product.name,
    'product_sku': product.sku,
    'product_price': product.price,
    'quantity': quantity,
    'discount': discount,
    'discount_is_percent': discountIsPercent,
  };

  static CartItem fromJson(Map<String, dynamic> json, Product product) => CartItem(
    product: product,
    quantity: json['quantity'] as int? ?? 1,
    discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    discountIsPercent: json['discount_is_percent'] as bool? ?? false,
  );
}

class POSController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = Get.find<AuthService>();
  final SyncService _syncService = Get.find<SyncService>();
  
  // Cart management
  final RxList<CartItem> _cartItems = <CartItem>[].obs;
  final RxDouble _totalAmount = 0.0.obs;
  final RxDouble _totalDiscount = 0.0.obs;
  final RxDouble _cashAmount = 0.0.obs;
  final RxDouble _changeAmount = 0.0.obs;
  
  // Products & inventory
  final RxList<Product> _products = <Product>[].obs;
  final RxList<Product> _filteredProducts = <Product>[].obs;
  final RxString _searchQuery = ''.obs;

  // Categories
  final RxList<Category> _categories = <Category>[].obs;
  final Rxn<int> _selectedCategoryId = Rxn<int>(); // null = Semua

  // Customers
  final RxList<Customer> _customers = <Customer>[].obs;
  final Rxn<Customer> _selectedCustomer = Rxn<Customer>();
  
  // Transaction state
  final RxBool _isProcessingTransaction = false.obs;
  final RxString _selectedPaymentMethod = 'cash'.obs;
  final RxBool _isLoadingProducts = false.obs;

  // Multi-payment support
  // Each entry: {'method': 'cash'|'debit'|'credit'|'qris', 'amount': double}
  final RxList<Map<String, dynamic>> _paymentEntries = <Map<String, dynamic>>[].obs;
  final RxDouble _totalPaid = 0.0.obs;

  // Hold/Resume
  final RxList<Map<String, dynamic>> _heldTransactions = <Map<String, dynamic>>[].obs;

  // Customer Display debounce timer
  Timer? _displayDebounceTimer;

  // Getters
  List<CartItem> get cartItems => _cartItems;
  List<Product> get products => _products;
  List<Product> get filteredProducts => _filteredProducts;
  List<Category> get categories => _categories;
  int? get selectedCategoryId => _selectedCategoryId.value;
  List<Customer> get customers => _customers;
  Customer? get selectedCustomer => _selectedCustomer.value;
  double get totalAmount => _totalAmount.value;
  double get totalDiscount => _totalDiscount.value;
  double get cashAmount => _cashAmount.value;
  double get changeAmount => _changeAmount.value;
  String get searchQuery => _searchQuery.value;
  bool get isProcessingTransaction => _isProcessingTransaction.value;
  bool get isLoadingProducts => _isLoadingProducts.value;
  String get selectedPaymentMethod => _selectedPaymentMethod.value;
  bool get hasItemsInCart => _cartItems.isNotEmpty;

  // Multi-payment getters
  List<Map<String, dynamic>> get paymentEntries => _paymentEntries;
  double get totalPaid => _totalPaid.value;
  double get remainingAmount => totalAmount - totalPaid;
  bool get canProcessPayment => _paymentEntries.isEmpty
      ? cashAmount >= totalAmount
      : totalPaid >= totalAmount;

  // Hold/Resume getters
  List<Map<String, dynamic>> get heldTransactions => _heldTransactions;
  int get heldTransactionCount => _heldTransactions.length;

  @override
  void onInit() {
    super.onInit();
    _initData();
    loadCustomers();
    loadHeldTransactions();
  }

  /// Init: load local first, then sync from backend if online
  Future<void> _initData() async {
    await loadCategories();
    await loadProducts();
    final hasInternet = await ConnectivityUtils.hasInternetConnection();
    if (hasInternet) {
      await syncCategoriesFromBackend(silent: true);
      await syncProductsFromBackend(silent: true);
    }
  }

  /// Load categories from local database
  Future<void> loadCategories() async {
    try {
      final results = await _db.query(
        DatabaseTables.categories,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );
      _categories.value = results.map((map) => Category.fromDatabase(map)).toList();
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  /// Sync categories dari backend
  Future<void> syncCategoriesFromBackend({bool silent = false}) async {
    final token = _authService.authToken;
    if (token.isEmpty) return;
    try {
      final resp = await http.get(
        Uri.parse('${AppConstants.baseUrl}/categories?per_page=200'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return;

      final raw = jsonDecode(resp.body)['data'];
      final List list = raw is List ? raw : (raw['data'] as List? ?? []);

      await _db.delete(DatabaseTables.categories);
      for (final c in list) {
        await _db.insert(DatabaseTables.categories, {
          'id':          c['id'],
          if (c['merchant_id'] != null) 'merchant_id': c['merchant_id'],
          'name':        c['name'] as String,
          if (c['description'] != null) 'description': c['description'],
          'is_active':   (c['is_active'] == true || c['is_active'] == 1) ? 1 : 0,
          'created_at':  c['created_at'] ?? DateTime.now().toIso8601String(),
          if (c['updated_at'] != null) 'updated_at': c['updated_at'],
        });
      }
      await loadCategories();
    } catch (e) {
      print('Error syncing categories: $e');
    }
  }

  /// Select category filter (null = Semua)
  void selectCategory(int? categoryId) {
    _selectedCategoryId.value = categoryId;
    _applyFilter();
  }

  /// Load products from local database
  Future<void> loadProducts() async {
    try {
      final results = await _db.query(
        DatabaseTables.products,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      _products.value = results.map((map) => Product.fromDatabase(map)).toList();
      _applyFilter();
    } catch (e) {
      print('Error loading products: $e');
      Get.snackbar('Error', 'Failed to load products');
    }
  }

  /// Sync products dari backend + stock sesuai branch aktif
  Future<void> syncProductsFromBackend({bool silent = false}) async {
    final token    = _authService.authToken;
    final branchId = _authService.selectedBranch?.id ?? _authService.currentUser?.branchId;
    if (token.isEmpty) return;

    _isLoadingProducts.value = true;
    try {
      // ── 0. Sync kategori terlebih dahulu ──
      await syncCategoriesFromBackend(silent: true);

      // ── 1. Ambil semua produk ──
      final productResp = await http.get(
        Uri.parse('${AppConstants.baseUrl}/products?per_page=500'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (productResp.statusCode == 401) {
        if (!silent) Get.snackbar('Sesi Expired', 'Silakan login ulang',
            backgroundColor: Colors.orange.withValues(alpha: 0.9), colorText: Colors.white);
        return;
      }
      if (productResp.statusCode != 200) {
        if (!silent) Get.snackbar('Gagal', 'Server error: ${productResp.statusCode}',
            backgroundColor: Colors.red.withValues(alpha: 0.9), colorText: Colors.white);
        return;
      }

      final rawProducts = jsonDecode(productResp.body)['data'];
      final List productList = rawProducts is List
          ? rawProducts
          : (rawProducts['data'] as List? ?? []);

      // ── 2. Simpan produk ke SQLite (local_stock = 0, diisi step 3) ──
      await _db.delete(DatabaseTables.products);
      for (final p in productList) {
        await _db.insert(DatabaseTables.products, {
          'id':          p['id'],
          'merchant_id': p['merchant_id'],
          'category_id': p['category_id'],
          'name':        p['name'],
          'sku':         p['sku'],
          'barcode':     p['barcode'],
          'description': p['description'],
          'price':       _toDouble(p['price']),
          'cost':        _toDouble(p['cost']),
          'unit':        p['unit'] ?? 'pcs',
          'min_stock':   _toInt(p['min_stock']),
          'image':       p['image'],
          'local_stock': 0,
          'is_active':   (p['is_active'] == true || p['is_active'] == 1) ? 1 : 0,
          'is_synced':   1,
          'synced_at':   DateTime.now().toIso8601String(),
          'created_at':  p['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at':  p['updated_at'],
        });
      }

      // ── 3. Ambil & update stock sesuai branch aktif ──
      if (branchId != null) {
        await _syncStockForBranch(token, branchId);
      }

      // ── 4. Reload dari local DB ──
      await loadProducts();

      if (!silent) {
        Get.snackbar(
          'Berhasil',
          '${productList.length} produk${branchId != null ? " (cabang #$branchId)" : ""} diperbarui',
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
        );
      }

    } on TimeoutException {
      print('Error syncing products: timeout');
      if (!silent) Get.snackbar('Timeout', 'Server tidak merespons',
          backgroundColor: Colors.orange.withValues(alpha: 0.9),
          colorText: Colors.white, duration: const Duration(seconds: 4));
    } on SocketException catch (e) {
      print('Error syncing products (socket): $e');
      if (!silent) Get.snackbar('Koneksi Gagal', 'Periksa jaringan atau URL server',
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white, duration: const Duration(seconds: 4));
    } catch (e) {
      print('Error syncing products: $e');
      if (!silent) Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white, duration: const Duration(seconds: 4));
    } finally {
      _isLoadingProducts.value = false;
    }
  }

  /// Ambil stock per branch dari /stocks dan update local_stock di SQLite
  Future<void> _syncStockForBranch(String token, int branchId) async {
    try {
      int page = 1;
      bool hasMore = true;
      while (hasMore) {
        final resp = await http.get(
          Uri.parse('${AppConstants.baseUrl}/stocks?branch_id=$branchId&per_page=200&page=$page'),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        if (resp.statusCode != 200) break;

        final rawStocks = jsonDecode(resp.body)['data'];
        final List stockList = rawStocks is List
            ? rawStocks
            : (rawStocks['data'] as List? ?? []);

        for (final s in stockList) {
          final productId = s['product_id'] ?? s['product']?['id'];
          final qty       = _toInt(s['quantity']);
          if (productId != null) {
            await _db.update(
              DatabaseTables.products,
              {'local_stock': qty},
              where: 'id = ?',
              whereArgs: [productId],
            );
          }
        }

        // Cek apakah ada halaman berikutnya
        final meta     = rawStocks is Map ? rawStocks['meta'] : null;
        final lastPage = _toInt(meta?['last_page'] ?? 1);
        hasMore = page < lastPage;
        page++;
      }
    } catch (e) {
      print('Error syncing stock branch $branchId: $e');
    }
  }

  /// Parse nilai apapun (String/int/double/null) menjadi double
  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  /// Parse nilai apapun (String/int/null) menjadi int
  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  /// Load customers from local database
  Future<void> loadCustomers() async {
    try {
      final results = await _db.query(
        DatabaseTables.customers,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      _customers.value = results.map((map) => Customer.fromDatabase(map)).toList();
    } catch (e) {
      print('Error loading customers: $e');
    }
  }

  /// Search products (delegates to _applyFilter)
  void searchProducts(String query) {
    _searchQuery.value = query;
    _applyFilter();
  }

  /// Apply both search query and category filter
  void _applyFilter() {
    final query      = _searchQuery.value.toLowerCase();
    final categoryId = _selectedCategoryId.value;

    _filteredProducts.value = _products.where((p) {
      final matchesCategory = categoryId == null || p.categoryId == categoryId;
      final matchesSearch   = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Add product to cart dengan validasi stok
  void addToCart(Product product) {
    final stock = product.localStock ?? 0;

    // Cek apakah stok tersedia
    if (stock <= 0) {
      Get.snackbar(
        'Stok Habis',
        '${product.name} sudah habis',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 2),
        icon: const Icon(Icons.warning_rounded, color: Colors.white),
      );
      return;
    }

    final existingIndex =
        _cartItems.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final currentQty = _cartItems[existingIndex].quantity;
      // Cek apakah qty di keranjang sudah melebihi stok
      if (currentQty >= stock) {
        Get.snackbar(
          'Stok Tidak Cukup',
          'Stok ${product.name} hanya $stock',
          snackPosition:   SnackPosition.TOP,
          backgroundColor: Colors.orange.shade700,
          colorText:       Colors.white,
          margin:          const EdgeInsets.all(12),
          duration:        const Duration(seconds: 2),
        );
        return;
      }
      _cartItems[existingIndex].quantity++;
      _cartItems.refresh();
    } else {
      _cartItems.add(CartItem(product: product));
    }

    _updateCartTotals();
  }

  /// Cari produk berdasarkan barcode / SKU lalu tambah ke cart
  void addToCartByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;
    final q = barcode.trim().toLowerCase();
    final product = _products.firstWhereOrNull(
      (p) => (p.barcode?.toLowerCase() == q) || p.sku.toLowerCase() == q,
    );
    if (product == null) {
      Get.snackbar(
        'Tidak Ditemukan',
        'Produk dengan barcode "$barcode" tidak ditemukan',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    addToCart(product);
  }

  /// Remove product from cart
  void removeFromCart(int productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    _updateCartTotals();
  }

  /// Update cart item quantity dengan validasi stok
  void updateCartItemQuantity(int productId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        final stock = _cartItems[index].product.localStock ?? 0;
        if (quantity > stock) {
          Get.snackbar(
            'Stok Tidak Cukup',
            'Stok ${_cartItems[index].product.name} hanya $stock',
            snackPosition:   SnackPosition.TOP,
            backgroundColor: Colors.orange.shade700,
            colorText:       Colors.white,
            margin:          const EdgeInsets.all(12),
            duration:        const Duration(seconds: 2),
          );
          return;
        }
        _cartItems[index].quantity = quantity;
        _cartItems.refresh();
      }
      _updateCartTotals();
    }
  }

  /// Update cart item discount
  void updateCartItemDiscount(int productId, double discount, {bool isPercent = false}) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cartItems[index].discount = discount;
      _cartItems[index].discountIsPercent = isPercent;
      _cartItems.refresh();
      _updateCartTotals();
    }
  }

  /// Update cart totals
  void _updateCartTotals() {
    double total = 0.0;
    double discount = 0.0;

    for (final item in _cartItems) {
      total += item.subtotal;
      discount += item.totalDiscount;
    }

    _totalAmount.value = total;
    _totalDiscount.value = discount;

    // Update change amount
    _updateChangeAmount();

    // Push ke customer display (debounce 1 detik)
    _scheduleDisplayUpdate();
  }

  /// Jadwalkan push cart ke customer display (debounce 1 detik)
  void _scheduleDisplayUpdate() {
    _displayDebounceTimer?.cancel();
    _displayDebounceTimer = Timer(const Duration(milliseconds: 300), _pushDisplayUpdate);
  }

  /// Kirim data cart ke VPS untuk ditampilkan di customer display
  Future<void> _pushDisplayUpdate() async {
    final token    = _authService.authToken;
    final branchId = _authService.selectedBranch?.id ?? _authService.currentUser?.branchId;
    final user     = _authService.currentUser;

    if (token.isEmpty || branchId == null) return;

    // Bangun payload items dari cart saat ini
    final items = _cartItems.map((item) => {
      'product_name': item.product.name,
      'quantity':     item.quantity,
      'subtotal':     item.subtotal,
      'discount':     item.totalDiscount,
    }).toList();

    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/display/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'branch_id':  branchId,
          'store_name': user?.companyName ?? 'Toko',
          'items':      items,
          'total':      _totalAmount.value,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silent — tidak boleh mengganggu UI kasir
    }
  }

  @override
  void onClose() {
    _displayDebounceTimer?.cancel();
    // Clear display saat kasir logout / controller di-dispose
    _clearDisplayOnServer();
    super.onClose();
  }

  /// Reset tampilan customer display ke kosong
  Future<void> _clearDisplayOnServer() async {
    final token    = _authService.authToken;
    final branchId = _authService.selectedBranch?.id ?? _authService.currentUser?.branchId;
    if (token.isEmpty || branchId == null) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/display/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':        'application/json',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'branch_id':  branchId,
          'store_name': _authService.currentUser?.companyName ?? 'Toko',
          'items':      <dynamic>[],
          'total':      0,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Update cash amount
  void updateCashAmount(double amount) {
    _cashAmount.value = amount;
    _updateChangeAmount();
  }

  /// Update change amount
  void _updateChangeAmount() {
    _changeAmount.value = cashAmount - totalAmount;
  }

  /// Set payment method (legacy single method)
  void setPaymentMethod(String method) {
    _selectedPaymentMethod.value = method;
  }

  // ─── Multi-Payment Methods ─────────────────────────────────────────────────

  /// Tambah payment entry ke list
  void addPaymentEntry(String method, double amount) {
    if (amount <= 0) return;
    _paymentEntries.add({'method': method, 'amount': amount});
    _recalcTotalPaid();
  }

  /// Hapus payment entry dari list
  void removePaymentEntry(int index) {
    if (index >= 0 && index < _paymentEntries.length) {
      _paymentEntries.removeAt(index);
      _recalcTotalPaid();
    }
  }

  /// Clear semua payment entries
  void clearPaymentEntries() {
    _paymentEntries.clear();
    _totalPaid.value = 0.0;
  }

  void _recalcTotalPaid() {
    _totalPaid.value = _paymentEntries.fold(
        0.0, (sum, e) => sum + ((e['amount'] as num).toDouble()));
  }

  // ─── Hold / Resume Transaction ─────────────────────────────────────────────

  /// Tahan transaksi saat ini ke database
  Future<void> holdTransaction({String? label}) async {
    if (_cartItems.isEmpty) {
      Get.snackbar('Keranjang Kosong', 'Tidak ada item untuk ditahan',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white);
      return;
    }

    try {
      final cartJson = jsonEncode(_cartItems.map((item) => item.toJson()).toList());
      final now = DateTime.now().toIso8601String();
      final customer = _selectedCustomer.value;

      await _db.insert(DatabaseTables.heldTransactions, {
        'label': label ?? 'Transaksi ${DateFormat('HH:mm').format(DateTime.now())}',
        'cart_data': cartJson,
        'customer_id': customer?.id,
        'customer_name': customer?.name,
        'total': totalAmount,
        'created_at': now,
      });

      _clearCart();
      await loadHeldTransactions();

      Get.snackbar('Transaksi Ditahan',
          'Transaksi disimpan, lanjutkan nanti',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF4CAF50),
          colorText: Colors.white,
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Error', 'Gagal menahan transaksi: $e');
    }
  }

  /// Load semua held transactions dari database
  Future<void> loadHeldTransactions() async {
    try {
      final results = await _db.query(
        DatabaseTables.heldTransactions,
        orderBy: 'created_at DESC',
      );
      _heldTransactions.value = results;
    } catch (e) {
      print('Error loading held transactions: $e');
    }
  }

  /// Resume transaksi yang ditahan (ganti cart saat ini)
  Future<void> resumeTransaction(int holdId) async {
    try {
      final results = await _db.query(
        DatabaseTables.heldTransactions,
        where: 'id = ?',
        whereArgs: [holdId],
      );
      if (results.isEmpty) return;

      final held = results.first;
      final cartData = jsonDecode(held['cart_data'] as String) as List;

      // Restore cart items
      final restoredItems = <CartItem>[];
      for (final itemJson in cartData) {
        final productId = itemJson['product_id'] as int?;
        if (productId == null) continue;
        final productResults = await _db.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [productId],
        );
        if (productResults.isEmpty) continue;
        final product = Product.fromDatabase(productResults.first);
        restoredItems.add(CartItem.fromJson(Map<String, dynamic>.from(itemJson), product));
      }

      // Restore customer jika ada
      final customerId = held['customer_id'] as int?;
      if (customerId != null) {
        final custResults = await _db.query(
          DatabaseTables.customers,
          where: 'id = ?',
          whereArgs: [customerId],
        );
        if (custResults.isNotEmpty) {
          _selectedCustomer.value = Customer.fromDatabase(custResults.first);
        }
      }

      // Set cart
      _cartItems.value = restoredItems;
      _updateCartTotals();

      // Hapus dari held_transactions
      await _db.delete(DatabaseTables.heldTransactions,
          where: 'id = ?', whereArgs: [holdId]);
      await loadHeldTransactions();

      Get.snackbar('Transaksi Dilanjutkan',
          '${restoredItems.length} item dikembalikan ke keranjang',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF2196F3),
          colorText: Colors.white,
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Error', 'Gagal melanjutkan transaksi: $e');
    }
  }

  /// Hapus held transaction
  Future<void> deleteHeldTransaction(int holdId) async {
    await _db.delete(DatabaseTables.heldTransactions,
        where: 'id = ?', whereArgs: [holdId]);
    await loadHeldTransactions();
  }

  /// Generate invoice number
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyyMMdd');
    final timeFormat = DateFormat('HHmmss');
    
    return 'INV-${dateFormat.format(now)}-${timeFormat.format(now)}';
  }

  /// Process payment and create sale
  Future<bool> processPayment({String? notes}) async {
    // Tentukan mode: multi-payment atau single
    final isMultiPayment = _paymentEntries.isNotEmpty;

    if (!canProcessPayment) {
      Get.snackbar(
        'Pembayaran Kurang',
        isMultiPayment
            ? 'Total pembayaran belum mencukupi (kurang ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(remainingAmount)})'
            : 'Jumlah uang tidak mencukupi',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText:       Colors.white,
      );
      return false;
    }

    if (_cartItems.isEmpty) {
      Get.snackbar(
        'Keranjang Kosong',
        'Tambahkan produk ke keranjang terlebih dahulu',
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText:       Colors.white,
      );
      return false;
    }

    // Validasi stok sekali lagi sebelum proses (safety check)
    final insufficientItems = <String>[];
    for (final cartItem in _cartItems) {
      final stock = cartItem.product.localStock ?? 0;
      if (cartItem.quantity > stock) {
        insufficientItems.add(
            '${cartItem.product.name} (butuh ${cartItem.quantity}, ada $stock)');
      }
    }
    if (insufficientItems.isNotEmpty) {
      Get.snackbar(
        'Stok Tidak Cukup',
        insufficientItems.join('\n'),
        snackPosition:   SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText:       Colors.white,
        margin:          const EdgeInsets.all(12),
        duration:        const Duration(seconds: 4),
        icon: const Icon(Icons.warning_rounded, color: Colors.white),
      );
      return false;
    }

    _isProcessingTransaction.value = true;

    try {
      final invoiceNumber = _generateInvoiceNumber();
      final now = DateTime.now().toIso8601String();
      final user = _authService.currentUser;

      // Tentukan nilai cash, change, dan payment method
      final double effectiveCash = isMultiPayment ? totalPaid : cashAmount;
      final double effectiveChange = isMultiPayment
          ? (totalPaid - totalAmount)
          : changeAmount;
      // Untuk multi-payment: jika 1 metode → pakai metode itu, lebih dari 1 → 'mixed'
      final uniqueMethods = _paymentEntries.map((e) => e['method'] as String).toSet();
      final String effectivePaymentMethod = isMultiPayment
          ? (uniqueMethods.length == 1 ? uniqueMethods.first : 'mixed')
          : selectedPaymentMethod;

      // Create sale record — gunakan selectedBranch aktif, fallback ke user.branchId
      final sale = Sale(
        branchId: _authService.selectedBranch?.id ?? user?.branchId,
        customerId: _selectedCustomer.value?.id,
        invoiceNumber: invoiceNumber,
        subtotal: totalAmount + totalDiscount,
        discount: totalDiscount,
        tax: 0.0,
        total: totalAmount,
        cash: effectiveCash,
        change: effectiveChange,
        paymentMethod: effectivePaymentMethod,
        status: 'completed',
        notes: notes,
        cashierName: user?.name,
        createdAt: now,
        isSynced: false,
      );

      // Insert sale to local database
      final saleId = await _db.insert(DatabaseTables.sales, sale.toDatabase());

      // Insert sale items
      final saleItems = <SaleItem>[];
      for (final cartItem in _cartItems) {
        final saleItem = SaleItem(
          saleId: saleId,
          productId: cartItem.product.id!,
          productName: cartItem.product.name,
          price: cartItem.product.price,
          quantity: cartItem.quantity,
          discount: cartItem.discount,
          subtotal: cartItem.subtotal,
        );

        await _db.insert(DatabaseTables.saleItems, saleItem.toDatabase());
        saleItems.add(saleItem);

        // Update local stock
        await _updateLocalStock(cartItem.product.id!, -cartItem.quantity);
      }

      // Create sale with items for sync
      final saleWithItems = sale.copyWith(id: saleId, items: saleItems);

      // Add to sync queue with API format
      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.sales,
        operation: SyncOperation.create,
        recordId: saleId,
        data: saleWithItems.toApiJson(), // Use toApiJson() for backend compatibility
      );

      // Simpan payment entries sebelum clear cart
      final snapshotPaymentEntries = isMultiPayment
          ? List<Map<String, dynamic>>.from(_paymentEntries)
          : null;

      // Show success and clear cart
      Get.snackbar('Berhasil', 'Transaksi selesai!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF4CAF50),
          colorText: Colors.white,
          duration: const Duration(seconds: 2));
      _clearCart();

      // Refresh dashboard stats (penjualan hari ini, transaksi, aktivitas terbaru)
      if (Get.isRegistered<DashboardService>()) {
        Get.find<DashboardService>().loadDashboardData();
      }

      // Show receipt dialog
      _showReceiptDialog(
        sale.copyWith(id: saleId, items: saleItems),
        paymentEntries: snapshotPaymentEntries,
      );

      return true;
    } catch (e) {
      print('Transaction error: $e');
      Get.snackbar('Transaction Failed', e.toString());
      return false;
    } finally {
      _isProcessingTransaction.value = false;
    }
  }

  /// Update local stock
  Future<void> _updateLocalStock(int productId, int quantityChange) async {
    try {
      // Get current stock
      final results = await _db.query(
        DatabaseTables.products,
        columns: ['local_stock'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (results.isNotEmpty) {
        final currentStock = results.first['local_stock'] as int? ?? 0;
        final newStock = currentStock + quantityChange;

        // Update stock
        await _db.update(
          DatabaseTables.products,
          {'local_stock': newStock},
          where: 'id = ?',
          whereArgs: [productId],
        );

        // Reload products to reflect changes
        await loadProducts();
      }
    } catch (e) {
      print('Error updating local stock: $e');
    }
  }

  /// Show receipt dialog
  void _showReceiptDialog(Sale sale, {List<Map<String, dynamic>>? paymentEntries}) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final methodLabel = {
      'cash': 'Tunai',
      'debit': 'Debit',
      'credit': 'Kredit',
      'qris': 'QRIS',
    };
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1D26),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFFFF6B35), size: 40),
                    const SizedBox(height: 8),
                    const Text('Transaksi Berhasil',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(sale.createdAt)),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Body (scrollable untuk struk panjang)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _receiptRow('No. Invoice', sale.invoiceNumber,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26))),
                        _receiptRow('Kasir', sale.cashierName ?? '-'),
                        const SizedBox(height: 10),
                        Container(height: 1, color: const Color(0xFFF4F5F7)),
                        const SizedBox(height: 10),
                        // Items
                        ...?sale.items?.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.productName}  ×${item.quantity}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D26)),
                                    ),
                                  ),
                                  Text(currency.format(item.subtotal),
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26))),
                                ],
                              ),
                              if (item.discount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '  Diskon: -${currency.format(item.discount)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50)),
                                  ),
                                ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 10),
                        Container(height: 1, color: const Color(0xFFF4F5F7)),
                        const SizedBox(height: 10),
                        if (sale.discount > 0)
                          _receiptRow('Diskon', '-${currency.format(sale.discount)}',
                              valueColor: const Color(0xFF4CAF50)),
                        _receiptRow('Total', currency.format(sale.total),
                            bold: true, valueColor: const Color(0xFFFF6B35)),
                        const SizedBox(height: 6),
                        // Tampilkan payment entries (multi) atau single
                        if (paymentEntries != null && paymentEntries.isNotEmpty) ...[
                          ...paymentEntries.map((e) => _receiptRow(
                            methodLabel[e['method']] ?? e['method'].toString().toUpperCase(),
                            currency.format(e['amount'] as num),
                          )),
                          _receiptRow('Kembalian',
                              currency.format((paymentEntries.fold<double>(0.0,
                                      (s, e) => s + (e['amount'] as num).toDouble()) -
                                  sale.total)),
                              valueColor: const Color(0xFF4CAF50)),
                        ] else if (sale.paymentMethod == 'cash') ...[
                          _receiptRow('Tunai', currency.format(sale.cash)),
                          _receiptRow('Kembalian', currency.format(sale.change),
                              valueColor: const Color(0xFF4CAF50)),
                        ] else
                          _receiptRow('Pembayaran', sale.paymentMethod.toUpperCase()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Tutup', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              _printReceipt(sale, paymentEntries: paymentEntries);
            },
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Cetak'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1D26),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Print receipt — coba Bluetooth dulu, fallback ke PDF
  Future<void> _printReceipt(Sale sale, {List<Map<String, dynamic>>? paymentEntries}) async {
    // 1. Coba Bluetooth thermal printer
    try {
      final btService = Get.find<BluetoothPrinterService>();
      if (btService.savedPrinterAddress.value.isNotEmpty) {
        final success = await btService.printReceipt(sale, paymentEntries: paymentEntries);
        if (success) return;
        // Gagal BT → fallback ke PDF
        Get.snackbar(
          'Info',
          'Printer Bluetooth gagal, menggunakan PDF...',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (_) {}

    // 2. Fallback ke PDF (printing package)
    try {
      final printerService = Get.find<ThermalPrinterService>();
      await printerService.printReceipt(sale, paymentEntries: paymentEntries);
    } catch (_) {}
  }

  Widget _receiptRow(String label, String value,
      {bool bold = false, Color? valueColor, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          Text(value,
              style: style ??
                  TextStyle(
                    fontSize: bold ? 14 : 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1A1D26),
                  )),
        ],
      ),
    );
  }

  /// Clear cart
  void _clearCart() {
    _cartItems.clear();
    _totalAmount.value = 0.0;
    _totalDiscount.value = 0.0;
    _cashAmount.value = 0.0;
    _changeAmount.value = 0.0;
    _selectedCustomer.value = null;
    _paymentEntries.clear();
    _totalPaid.value = 0.0;
    // Reset customer display setelah transaksi selesai
    _displayDebounceTimer?.cancel();
    _pushDisplayUpdate();
  }

  /// Set customer
  void setCustomer(Customer customer) {
    _selectedCustomer.value = customer;
  }

  /// Clear customer
  void clearCustomer() {
    _selectedCustomer.value = null;
  }

  /// Add new customer
  Future<bool> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final customer = Customer(
        name: name,
        phone: phone,
        email: email,
        address: address,
        notes: notes,
        createdAt: now,
        isSynced: false,
      );

      final id = await _db.insert(DatabaseTables.customers, customer.toDatabase());
      
      // Add to sync queue
      await _syncService.addToSyncQueue(
        tableName: DatabaseTables.customers,
        operation: SyncOperation.create,
        recordId: id,
        data: customer.toApiJson(),
      );

      // Reload customers
      await loadCustomers();
      
      // Set as selected customer
      final newCustomer = customer.copyWith(id: id);
      setCustomer(newCustomer);

      Get.snackbar('Success', 'Customer added successfully');
      return true;
    } catch (e) {
      print('Error adding customer: $e');
      Get.snackbar('Error', 'Failed to add customer');
      return false;
    }
  }

  /// Get quick cash amounts
  List<double> getQuickCashAmounts() {
    final roundedTotal = (totalAmount / 1000).ceil() * 1000;
    return [
      roundedTotal.toDouble(),
      roundedTotal + 5000.0,
      roundedTotal + 10000.0,
      roundedTotal + 20000.0,
      50000.0,
      100000.0,
    ];
  }

  /// Apply discount to entire cart
  void applyCartDiscount(double discountPercent) {
    final discountAmount = totalAmount * (discountPercent / 100);
    
    // Distribute discount proportionally among items
    for (final item in _cartItems) {
      final itemDiscountRatio = item.subtotal / totalAmount;
      item.discount += discountAmount * itemDiscountRatio;
    }
    
    _updateCartTotals();
  }
}