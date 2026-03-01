import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';
import '../../core/utils/connectivity_utils.dart';
import '../../data/models/user_model.dart';
import '../../data/models/branch_model.dart';
import '../../data/models/subscription_model.dart';
import '../../data/models/app_pricing_model.dart';
import '../database/database_helper.dart';
import '../category/category_service.dart' show CategoryService;
import '../inventory/inventory_service.dart' show InventoryService;

class AuthService extends GetxService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final DatabaseHelper _db = DatabaseHelper();

  final Rxn<User> _currentUser             = Rxn<User>();
  final RxString _authToken                = ''.obs;
  final RxBool _isLoggedIn                 = false.obs;
  final RxBool _isLoading                  = false.obs;
  final RxList<Branch> _branches           = <Branch>[].obs;
  final Rxn<Branch> _selectedBranch        = Rxn<Branch>();
  final Rxn<SubscriptionInfo> _subscription = Rxn<SubscriptionInfo>();
  final Rx<AppPricing> _pricing = AppPricing.defaultPricing.obs;
  // null = lihat semua cabang (khusus owner), non-null = cabang tertentu
  final Rxn<int> viewBranchId              = Rxn<int>();

  User?             get currentUser    => _currentUser.value;
  String            get authToken      => _authToken.value;
  bool              get isLoggedIn     => _isLoggedIn.value;
  bool              get isLoading      => _isLoading.value;
  List<Branch>      get branches       => _branches;
  Branch?           get selectedBranch => _selectedBranch.value;
  SubscriptionInfo? get subscription   => _subscription.value;
  AppPricing        get pricing        => _pricing.value;

  /// true jika owner sedang mode lihat semua cabang
  bool get isViewingAllBranches =>
      (currentUser?.isOwner == true) && viewBranchId.value == null;

  /// Set filter branch untuk laporan (null = semua, int = branch tertentu)
  void setViewBranch(int? branchId) {
    viewBranchId.value = branchId;
  }

  /// Inisialisasi viewBranchId sesuai role:
  /// - Owner: default null (semua cabang)
  /// - Lainnya: default ke selectedBranch
  void initViewBranch() {
    if (currentUser?.isOwner == true) {
      viewBranchId.value = null; // semua cabang
    } else {
      viewBranchId.value = selectedBranch?.id;
    }
  }

  // Storage keys
  static const _keyToken          = 'auth_token';
  static const _keyUserData       = 'user_data';
  static const _keyBranches       = 'cached_branches';
  static const _keySelectedBranch = 'selected_branch_id';
  static const _keyCompanyCode    = 'cached_company_code';
  static const _keyCachedEmail    = 'cached_email';
  static const _keyCachedPwHash   = 'cached_password_hash';
  static const _keySubscription   = 'cached_subscription';
  static const _keyPricing        = 'cached_pricing';

  @override
  void onInit() {
    super.onInit();
    _loadStoredAuth();
  }

  // ─────────────────────────────────────────────
  // INIT - Load saved session
  // ─────────────────────────────────────────────

  Future<void> _loadStoredAuth() async {
    try {
      final token    = await _storage.read(key: _keyToken);
      final userData = await _storage.read(key: _keyUserData);

      if (token != null && userData != null) {
        _authToken.value    = token;
        _currentUser.value  = User.fromJson(jsonDecode(userData));
        _isLoggedIn.value   = true;

        // Load cached branches
        await _loadCachedBranches();

        // Load selected branch
        final branchJson = await _storage.read(key: _keySelectedBranch);
        if (branchJson != null) {
          _selectedBranch.value = Branch.fromJson(jsonDecode(branchJson));
        }
        initViewBranch();

        // Load cached subscription
        final subJson = await _storage.read(key: _keySubscription);
        if (subJson != null) {
          _subscription.value = SubscriptionInfo.fromJson(jsonDecode(subJson));
        }

        // Load cached pricing
        final pricingJson = await _storage.read(key: _keyPricing);
        if (pricingJson != null) {
          _pricing.value = AppPricing.fromJson(jsonDecode(pricingJson));
        }

        // Verify token jika online
        if (await ConnectivityUtils.hasInternetConnection()) {
          await _verifyTokenOnline();
          await refreshSubscription(); // refresh status terbaru dari server
        }
      }
    } catch (e) {
      debugPrint('Error loading stored auth: $e');
      await logout();
    }
  }

  /// Refresh status subscription dari server
  Future<void> refreshSubscription() async {
    try {
      final token = _authToken.value;
      if (token.isEmpty) return;
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/subscription'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (data['subscription'] != null) {
            _subscription.value = SubscriptionInfo.fromJson(data['subscription']);
            await _storage.write(key: _keySubscription, value: jsonEncode(data['subscription']));
          }
          if (data['pricing'] != null) {
            _pricing.value = AppPricing.fromJson(data['pricing'] as Map<String, dynamic>);
            await _storage.write(key: _keyPricing, value: jsonEncode(data['pricing']));
          }
        }
      }
    } catch (e) {
      debugPrint('refreshSubscription error: $e');
    }
  }

  Future<void> _loadCachedBranches() async {
    try {
      final branchesJson = await _storage.read(key: _keyBranches);
      if (branchesJson != null) {
        final list = (jsonDecode(branchesJson) as List)
            .map((b) => Branch.fromJson(b))
            .toList();
        _branches.assignAll(list);
      }
    } catch (e) {
      debugPrint('Error loading cached branches: $e');
    }
  }

  // ─────────────────────────────────────────────
  // REGISTER MERCHANT BARU
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> registerMerchant({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String merchantName,
    String? phone,
    String? businessType,
    String? address,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'name':                  name,
        'email':                 email,
        'password':              password,
        'password_confirmation': passwordConfirmation,
        'merchant_name':         merchantName,
        'phone':                 phone,
        'business_type':         businessType,
        'address':               address,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      return data['data'] as Map<String, dynamic>;
    }

    // Ambil pesan error pertama jika ada validation errors
    if (data['errors'] != null) {
      final errors = data['errors'] as Map<String, dynamic>;
      final firstMsg = (errors.values.first as List).first as String;
      throw Exception(firstMsg);
    }

    throw Exception(data['message'] ?? 'Pendaftaran gagal');
  }

  // ─────────────────────────────────────────────
  // CEK STATUS PENDAFTARAN
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> checkRegistrationStatus(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/check-registration'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as Map<String, dynamic>;
    }

    throw Exception(data['message'] ?? 'Email tidak ditemukan');
  }

  // ─────────────────────────────────────────────
  // LOOKUP COMPANY (Step 1 login)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> lookupCompany(String companyCode) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/lookup-company'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'company_code': companyCode.toUpperCase()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }

      throw Exception(data['message'] ?? 'Company not found');
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // LOGIN (Step 2 - dengan company_code)
  // ─────────────────────────────────────────────

  Future<LoginResult> login({
    required String companyCode,
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    _isLoading.value = true;
    try {
      if (await ConnectivityUtils.hasInternetConnection()) {
        return await _loginOnline(companyCode, email, password, rememberMe);
      } else {
        return await _loginOffline(companyCode, email, password);
      }
    } catch (e) {
      Get.snackbar('Login Gagal', e.toString().replaceAll('Exception: ', ''),
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return LoginResult.failed;
    } finally {
      _isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  // LOGIN SUPER ADMIN (tanpa company_code, online only)
  // ─────────────────────────────────────────────

  Future<LoginResult> loginSuperAdmin({
    required String email,
    required String password,
  }) async {
    _isLoading.value = true;
    try {
      if (!await ConnectivityUtils.hasInternetConnection()) {
        throw Exception('Login admin membutuhkan koneksi internet.');
      }
      return await _loginOnline('', email, password, true);
    } catch (e) {
      Get.snackbar('Login Gagal', e.toString().replaceAll('Exception: ', ''),
          backgroundColor: Colors.red.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return LoginResult.failed;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<LoginResult> _loginOnline(
      String companyCode, String email, String password, bool rememberMe) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'company_code': companyCode.toUpperCase(),
        'email':        email,
        'password':     password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final userData     = data['data']['user']     as Map<String, dynamic>;
      final merchantData = data['data']['merchant'] as Map<String, dynamic>?;  // nullable for super_admin
      final branchesData = (data['data']['branches'] as List?) ?? [];           // nullable for super_admin
      final token        = data['data']['token']    as String;

      // Gabungkan info company ke user object (hanya jika ada merchant)
      if (merchantData != null) {
        userData['company_code'] = merchantData['company_code'];
        userData['company_name'] = merchantData['name'];
      }

      final user     = User.fromJson(userData);
      final branches = branchesData.map((b) => Branch.fromJson(b)).toList();

      // Parse subscription info
      final subData = data['data']['subscription'] as Map<String, dynamic>?;
      if (subData != null) {
        _subscription.value = SubscriptionInfo.fromJson(subData);
        await _storage.write(key: _keySubscription, value: jsonEncode(subData));
      }
      // Parse pricing info
      final pricingData = data['data']['pricing'] as Map<String, dynamic>?;
      if (pricingData != null) {
        _pricing.value = AppPricing.fromJson(pricingData);
        await _storage.write(key: _keyPricing, value: jsonEncode(pricingData));
      }

      _authToken.value   = token;
      _currentUser.value = user;
      _branches.assignAll(branches);

      // Simpan ke secure storage
      if (rememberMe) {
        await _saveAuthData(user, token, companyCode, password, branches);
      }

      // Super admin: tidak perlu branch selection / master data download
      if (user.isSuperAdmin) {
        _isLoggedIn.value = true;
        return LoginResult.success;
      }

      // Jika cashier dan sudah punya branchId → auto-select branch
      if (user.isCashier && user.branchId != null) {
        final assignedBranch = branches.firstWhereOrNull(
          (b) => b.id == user.branchId,
        );
        if (assignedBranch != null) {
          _selectedBranch.value = assignedBranch;
          await _storage.write(
            key: _keySelectedBranch,
            value: jsonEncode(assignedBranch.toJson()),
          );
        }
      }

      // Download master data hanya jika subscription masih aktif
      final sub = _subscription.value;
      if (sub == null || sub.canAccess) {
        await _downloadMasterData(token);
      }

      _isLoggedIn.value = true;
      initViewBranch();

      // Cashier dengan branch sudah di-assign → langsung ke dashboard
      if (user.isCashier && _selectedBranch.value != null) {
        return LoginResult.success;
      }

      return LoginResult.needBranchSelection;
    }

    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<LoginResult> _loginOffline(
      String companyCode, String email, String password) async {
    if (companyCode.isEmpty) {
      throw Exception('Login admin membutuhkan koneksi internet.');
    }
    debugPrint('Attempting offline login: $email');

    final userData      = await _storage.read(key: _keyUserData);
    final storedToken   = await _storage.read(key: _keyToken);
    final cachedEmail   = await _storage.read(key: _keyCachedEmail);
    final cachedCode    = await _storage.read(key: _keyCompanyCode);
    final cachedPwHash  = await _storage.read(key: _keyCachedPwHash);

    if (userData == null || storedToken == null || cachedEmail == null) {
      throw Exception('Tidak ada data offline.\nSilakan login online terlebih dahulu.');
    }

    if (cachedEmail.toLowerCase() != email.toLowerCase()) {
      throw Exception('Email tidak cocok dengan akun yang tersimpan.');
    }

    if (cachedCode?.toUpperCase() != companyCode.toUpperCase()) {
      throw Exception('Kode company tidak cocok dengan data offline.');
    }

    // Verifikasi password (hash sederhana)
    if (cachedPwHash != null && cachedPwHash != password.hashCode.toString()) {
      debugPrint('Password hash tidak cocok, tetap lanjut offline mode');
    }

    final user = User.fromJson(jsonDecode(userData));
    await _loadCachedBranches();

    _currentUser.value = user;
    _authToken.value   = storedToken;
    _isLoggedIn.value  = true;

    // Cek apakah sudah ada branch tersimpan sebelumnya
    final branchJson = await _storage.read(key: _keySelectedBranch);
    if (branchJson != null) {
      _selectedBranch.value = Branch.fromJson(jsonDecode(branchJson));
    } else if (user.isCashier && user.branchId != null) {
      // Cashier belum punya cached branch → cari dari daftar branches
      final assignedBranch = _branches.firstWhereOrNull(
        (b) => b.id == user.branchId,
      );
      if (assignedBranch != null) {
        _selectedBranch.value = assignedBranch;
        await _storage.write(
          key: _keySelectedBranch,
          value: jsonEncode(assignedBranch.toJson()),
        );
      }
    }

    initViewBranch();

    Get.snackbar(
      'Mode Offline',
      'Login sebagai ${user.name}\nData akan tersinkron saat online.',
      backgroundColor: Colors.orange.withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
    );

    // Cashier dengan branch sudah di-assign → langsung ke dashboard
    if (user.isCashier && _selectedBranch.value != null) {
      return LoginResult.success;
    }

    return _branches.isEmpty
        ? LoginResult.success          // Tidak ada branch, langsung ke dashboard
        : LoginResult.needBranchSelection;
  }

  // ─────────────────────────────────────────────
  // PILIH CABANG (Step 3)
  // ─────────────────────────────────────────────

  Future<void> selectBranch(Branch branch) async {
    _selectedBranch.value = branch;

    // Update user dengan branchId terpilih
    if (_currentUser.value != null) {
      _currentUser.value = _currentUser.value!.copyWith(branchId: branch.id);
      await _storage.write(
        key: _keyUserData,
        value: jsonEncode(_currentUser.value!.toJson()),
      );
    }

    // Cache branch terpilih
    await _storage.write(
      key: _keySelectedBranch,
      value: jsonEncode(branch.toJson()),
    );

    _isLoggedIn.value = true;
    initViewBranch();
    debugPrint('Branch dipilih: ${branch.name} (id: ${branch.id})');
  }

  /// Update in-memory selected branch after settings save
  Future<void> updateSelectedBranch(Branch branch) async {
    _selectedBranch.value = branch;

    // Update cached branch in secure storage
    await _storage.write(
      key: _keySelectedBranch,
      value: jsonEncode(branch.toJson()),
    );

    // Update branches list too
    final idx = _branches.indexWhere((b) => b.id == branch.id);
    if (idx >= 0) {
      _branches[idx] = branch;
      await _storage.write(
        key: _keyBranches,
        value: jsonEncode(_branches.map((b) => b.toJson()).toList()),
      );
    }

    debugPrint('Branch diperbarui: ${branch.name} (id: ${branch.id})');
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  Future<void> _saveAuthData(User user, String token, String companyCode,
      String password, List<Branch> branches) async {
    await _storage.write(key: _keyToken,        value: token);
    await _storage.write(key: _keyUserData,     value: jsonEncode(user.toJson()));
    await _storage.write(key: _keyCachedEmail,  value: user.email);
    await _storage.write(key: _keyCompanyCode,  value: companyCode.toUpperCase());
    await _storage.write(key: _keyCachedPwHash, value: password.hashCode.toString());
    await _storage.write(
      key:   _keyBranches,
      value: jsonEncode(branches.map((b) => b.toJson()).toList()),
    );
    debugPrint('Credentials saved for offline access: ${user.name} (${user.role})');
  }

  Future<void> _verifyTokenOnline() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/profile'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept':        'application/json',
        },
      );
      if (response.statusCode != 200) {
        await logout();
      }
    } catch (e) {
      debugPrint('Token verification failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  // MASTER DATA DOWNLOAD
  // ─────────────────────────────────────────────

  Future<void> _downloadMasterData(String token) async {
    try {
      await Future.wait([
        _downloadProducts(token),
        _downloadCategories(token),
        _downloadCustomers(token),
      ]);
      debugPrint('Master data downloaded');
    } catch (e) {
      debugPrint('Failed to download master data: $e');
    }
  }

  /// Fetch ulang daftar branches dari server (untuk merchant yang baru dapat branch)
  Future<bool> refreshBranches() async {
    if (authToken.isEmpty) return false;
    if (!await ConnectivityUtils.hasInternetConnection()) return false;
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/branches'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawBranches = data['data'] as List? ?? [];
        final branches = rawBranches.map((b) => Branch.fromJson(b)).toList();
        _branches.assignAll(branches);
        // Update cache
        await _storage.write(
          key: _keyBranches,
          value: jsonEncode(branches.map((b) => b.toJson()).toList()),
        );
        return branches.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('refreshBranches error: $e');
      return false;
    }
  }

  /// Pull kategori terbaru dari server (bisa dipanggil kapan saja saat online)
  Future<bool> refreshCategoriesFromServer() async {
    if (authToken.isEmpty) return false;
    if (!await ConnectivityUtils.hasInternetConnection()) return false;
    try {
      await _downloadCategories(authToken);
      return true;
    } catch (e) {
      debugPrint('refreshCategoriesFromServer error: $e');
      return false;
    }
  }

  Future<void> _downloadProducts(String token) async {
    // per_page=500 agar semua produk terambil sekaligus
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/products?per_page=500'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data         = jsonDecode(response.body);
      final productsData = data['data'];
      final List products = productsData is List
          ? productsData
          : (productsData['data'] as List? ?? []);

      // Download stok per branch yang aktif
      final Map<int, int> stockMap = {};
      final branchId = _selectedBranch.value?.id;
      if (branchId != null) {
        try {
          final stockResp = await http.get(
            Uri.parse('${AppConstants.baseUrl}/stocks?branch_id=$branchId&per_page=500'),
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
          );
          if (stockResp.statusCode == 200) {
            final stockData  = jsonDecode(stockResp.body);
            final stocksData = stockData['data'];
            final List stocks = stocksData is List
                ? stocksData
                : (stocksData['data'] as List? ?? []);
            for (final s in stocks) {
              final productId = s['product_id'] as int?;
              final quantity  = s['quantity'] as int? ?? 0;
              if (productId != null) stockMap[productId] = quantity;
            }
            debugPrint('✅ Downloaded ${stocks.length} stock records for branch $branchId');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to download stocks: $e');
        }
      }

      await _db.delete(DatabaseTables.products);
      final now = DateTime.now().toIso8601String();
      for (final p in products) {
        final productId = p['id'] as int?;
        await _db.insert(DatabaseTables.products, {
          'id':          productId,
          'merchant_id': p['merchant_id'],
          'category_id': p['category_id'],
          'name':        p['name'],
          'sku':         p['sku'],
          'barcode':     p['barcode'],
          'description': p['description'],
          'price':       p['price'],
          'cost':        p['cost'],
          'unit':        p['unit'],
          'min_stock':   p['min_stock'],
          'image':       p['image'],
          'local_stock': productId != null ? (stockMap[productId] ?? 0) : 0,
          'is_active':   (p['is_active'] == true || p['is_active'] == 1) ? 1 : 0,
          'created_at':  p['created_at'] ?? now,
          'updated_at':  p['updated_at'],
          'is_synced':   1,
          'synced_at':   now,
        });
      }
      debugPrint('✅ Downloaded ${products.length} products');

      // Refresh in-memory list di InventoryService jika sudah teregistrasi
      try {
        if (Get.isRegistered<InventoryService>()) {
          await Get.find<InventoryService>().loadProducts();
        }
      } catch (_) {}
    }
  }

  /// Pull produk terbaru dari server (bisa dipanggil kapan saja saat online)
  Future<bool> refreshProductsFromServer() async {
    if (authToken.isEmpty) return false;
    if (!await ConnectivityUtils.hasInternetConnection()) return false;
    try {
      await _downloadProducts(authToken);
      return true;
    } catch (e) {
      debugPrint('refreshProductsFromServer error: $e');
      return false;
    }
  }

  Future<void> _downloadCategories(String token) async {
    // per_page=500 agar semua kategori terambil sekaligus (hindari pagination)
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/categories?per_page=500'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data           = jsonDecode(response.body);
      final categoriesData = data['data'];
      // Laravel paginate → {data:[...], total:...}; jika langsung List → pakai langsung
      final List categories = categoriesData is List
          ? categoriesData
          : (categoriesData['data'] as List? ?? []);

      await _db.delete(DatabaseTables.categories);
      final now = DateTime.now().toIso8601String();
      for (final c in categories) {
        final branch = c['branch'] as Map<String, dynamic>?;
        await _db.insert(DatabaseTables.categories, {
          'id':          c['id'],
          'merchant_id': c['merchant_id'],
          'branch_id':   c['branch_id'],
          'branch_name': branch?['name'],
          'name':        c['name'],
          'description': c['description'],
          'is_active':   (c['is_active'] == true || c['is_active'] == 1) ? 1 : 0,
          'is_synced':   1,
          'synced_at':   now,
          'created_at':  c['created_at'] ?? now,
          'updated_at':  c['updated_at'],
        });
      }
      debugPrint('✅ Downloaded ${categories.length} categories');

      // Refresh in-memory list di CategoryService jika sudah teregistrasi
      try {
        if (Get.isRegistered<CategoryService>()) {
          await Get.find<CategoryService>().loadCategories();
        }
      } catch (_) {}
    }
  }

  Future<void> _downloadCustomers(String token) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/customers'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data          = jsonDecode(response.body);
      final customersData = data['data'];
      final customers     = customersData is List ? customersData : (customersData['data'] as List? ?? []);

      await _db.delete(DatabaseTables.customers);
      for (final c in customers) {
        await _db.insert(DatabaseTables.customers, {
          'id':          c['id'],
          'merchant_id': c['merchant_id'],
          'name':        c['name'],
          'phone':       c['phone'],
          'email':       c['email'],
          'address':     c['address'],
          'is_active':   (c['is_active'] == true) ? 1 : 0,
          'created_at':  c['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at':  c['updated_at'],
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────

  Future<void> logout() async {
    try {
      if (await ConnectivityUtils.hasInternetConnection() && authToken.isNotEmpty) {
        await http.post(
          Uri.parse('${AppConstants.baseUrl}/auth/logout'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept':        'application/json',
          },
        );
      }
    } catch (e) {
      debugPrint('Logout API failed: $e');
    }

    await _storage.deleteAll();
    await _db.clearAllData();

    _currentUser.value    = null;
    _authToken.value      = '';
    _isLoggedIn.value     = false;
    _branches.clear();
    _selectedBranch.value = null;

    Get.snackbar('Sampai Jumpa', 'Logout berhasil');
  }

  // ─────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────

  Map<String, String> getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
  }

  bool hasPermission(String permission) {
    if (currentUser == null) return false;
    switch (currentUser!.role) {
      case 'owner':
        return true;
      case 'manager':
        return !['delete_sales', 'manage_users'].contains(permission);
      case 'cashier':
        return ['create_sales', 'view_products', 'view_customers'].contains(permission);
      default:
        return false;
    }
  }
}

/// Hasil dari proses login
enum LoginResult {
  success,              // Langsung masuk (tidak perlu pilih branch)
  needBranchSelection,  // Perlu pilih cabang
  failed,               // Gagal login
}
