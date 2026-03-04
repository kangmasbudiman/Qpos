import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'presentation/screens/login_screen.dart';
import 'presentation/screens/subscription_expired_screen.dart';
import 'presentation/widgets/payzen_logo.dart';
import 'presentation/screens/forgot_password_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/check_registration_screen.dart';
import 'presentation/screens/super_admin_login_screen.dart';
import 'presentation/screens/super_admin/super_admin_dashboard_screen.dart';
import 'presentation/screens/super_admin/registration_list_screen.dart';
import 'presentation/screens/super_admin/registration_detail_screen.dart';
import 'presentation/screens/super_admin/merchant_list_screen.dart';
import 'services/registration/registration_service.dart';
import 'presentation/screens/branch_selection_screen.dart';
import 'presentation/screens/dashboard_screen_new.dart';
import 'presentation/screens/pos_screen.dart';
import 'presentation/screens/checkout_screen.dart';
import 'presentation/screens/inventory_screen.dart';
import 'presentation/screens/category_screen.dart';
import 'presentation/screens/sync_debug_screen.dart';
import 'presentation/screens/purchase_screen.dart';
import 'presentation/screens/supplier_screen.dart';
import 'presentation/screens/sales_report_screen.dart';
import 'presentation/screens/inventory_report_screen.dart';
import 'presentation/screens/profit_loss_screen.dart';
import 'services/report/profit_loss_service.dart';
import 'presentation/screens/stock_opname_screen.dart';
import 'presentation/screens/stock_transfer_screen.dart';
import 'services/inventory/stock_opname_service.dart';
import 'services/inventory/low_stock_notification_service.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/staff_screen.dart';
import 'presentation/screens/branch_management_screen.dart';
import 'presentation/controllers/connectivity_controller.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/category_controller.dart';
import 'presentation/controllers/supplier_controller.dart';
import 'services/auth/auth_service.dart';
import 'services/sync/sync_service.dart';
import 'services/sync/sync_settings_service.dart';
import 'services/sync/auto_sync_service.dart';
import 'services/inventory/inventory_service.dart';
import 'services/category/category_service.dart';
import 'services/purchase/purchase_service.dart';
import 'services/supplier/supplier_service.dart';
import 'services/dashboard/dashboard_service.dart';
import 'services/print/thermal_printer_service.dart';
import 'services/print/bluetooth_printer_service.dart';
import 'services/theme/theme_service.dart';
import 'services/language/language_service.dart';
import 'services/backup/backup_service.dart';
import 'services/branch/branch_service.dart';
import 'services/loyalty/loyalty_service.dart';
import 'services/shift/shift_service.dart';
import 'presentation/screens/loyalty_screen.dart';
import 'presentation/screens/shift_history_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale data for intl package (required for DateFormat with locale)
  await initializeDateFormatting('id_ID', null);

  // Initialize services
  await _initializeServices();

  runApp(POSApp());
}

Future<void> _initializeServices() async {
  // Register services in dependency injection
  Get.put(AuthService(), permanent: true);
  Get.put(SyncService(), permanent: true);
  // SyncSettingsService harus siap sebelum AutoSyncService (async load dari storage)
  final syncSettings = SyncSettingsService();
  await syncSettings.loadFromStorage();
  Get.put(syncSettings, permanent: true);
  // ThemeService harus siap sebelum app render agar theme tidak flicker
  final themeService = ThemeService();
  await themeService.loadFromStorage();
  Get.put(themeService, permanent: true);
  // LanguageService harus siap sebelum app render agar bahasa tidak flicker
  final languageService = LanguageService();
  await languageService.loadFromStorage();
  Get.put(languageService, permanent: true);
  Get.put(AutoSyncService(), permanent: true);
  Get.put(ConnectivityController(), permanent: true);
  Get.put(InventoryService(), permanent: true);
  Get.put(CategoryService(), permanent: true);
  Get.put(PurchaseService(), permanent: true);
  Get.put(SupplierService(), permanent: true);
  Get.put(DashboardService(), permanent: true);
  Get.put(ProfitLossService(), permanent: true);
  Get.put(StockOpnameService(), permanent: true);
  Get.put(LowStockNotificationService(), permanent: true);
  Get.put(ThermalPrinterService(), permanent: true);
  Get.put(BluetoothPrinterService(), permanent: true);
  Get.put(BackupService(), permanent: true);
  Get.put(BranchService(), permanent: true);
  Get.put(LoyaltyService(), permanent: true);
  Get.put(ShiftService(), permanent: true);
  Get.put(RegistrationService(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(CategoryController(), permanent: true);
  Get.put(SupplierController(), permanent: true);
}

class POSApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Obx(() {
          final themeService = Get.find<ThemeService>();
          final isDark = themeService.isDarkMode.value; // subscribe ke Rx
          // subscribe ke locale agar rebuild saat bahasa berubah
          Get.find<LanguageService>().locale.value;
          return GetMaterialApp(
            title: 'PAYZEN',
            debugShowCheckedModeBanner: false,
            theme:      AppTheme.lightTheme,
            darkTheme:  AppTheme.darkTheme,
            themeMode:  isDark ? ThemeMode.dark : ThemeMode.light,
            // ── Global page transition ──────────────────────────
            defaultTransition: Transition.fadeIn,
            transitionDuration: const Duration(milliseconds: 220),
            initialRoute: '/splash',
            getPages: [
              GetPage(name: '/splash',
                page: () => SplashScreen(),
                transition: Transition.fadeIn),
              GetPage(name: '/login',
                page: () => LoginScreen(),
                transition: Transition.fadeIn,
                transitionDuration: const Duration(milliseconds: 350)),
              GetPage(name: '/forgot-password',
                page: () => const ForgotPasswordScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/register',
                page: () => const RegisterScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/check-registration',
                page: () => const CheckRegistrationScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/super-admin-login',
                page: () => const SuperAdminLoginScreen(),
                transition: Transition.fadeIn,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/super-admin',
                page: () => const SuperAdminDashboardScreen(),
                transition: Transition.fadeIn,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/registrations',
                page: () => const RegistrationListScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/registrations/:id',
                page: () => const RegistrationDetailScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/merchants',
                page: () => const MerchantListScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/branch-selection',
                page: () => BranchSelectionScreen(),
                transition: Transition.downToUp,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/dashboard',
                page: () => DashboardScreenNew(),
                transition: Transition.fadeIn,
                transitionDuration: const Duration(milliseconds: 300)),
              GetPage(name: '/pos',
                page: () => POSScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/checkout',
                page: () => CheckoutScreen(),
                transition: Transition.upToDown,
                transitionDuration: const Duration(milliseconds: 280)),
              GetPage(name: '/inventory',
                page: () => InventoryScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/categories',
                page: () => CategoryScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/sync-debug',
                page: () => SyncDebugScreen(),
                transition: Transition.rightToLeft),
              GetPage(name: '/purchases',
                page: () => PurchaseScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/suppliers',
                page: () => SupplierScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/sales-report',
                page: () => SalesReportScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/inventory-report',
                page: () => InventoryReportScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/profit-loss',
                page: () => const ProfitLossScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/settings',
                page: () => SettingsScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/staff',
                page: () => StaffScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/branch-management',
                page: () => const BranchManagementScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/stock-opname',
                page: () => const StockOpnameScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/stock-transfer',
                page: () => const StockTransferScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/loyalty',
                page: () => const LoyaltyScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/shift-history',
                page: () => const ShiftHistoryScreen(),
                transition: Transition.rightToLeft,
                transitionDuration: const Duration(milliseconds: 250)),
              GetPage(name: '/subscription-expired',
                page: () => const SubscriptionExpiredScreen(),
                transition: Transition.fadeIn,
                transitionDuration: const Duration(milliseconds: 300)),
            ],
          );
        });
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final authService = Get.find<AuthService>();

    // Tunggu auth service load data tersimpan
    await Future.delayed(const Duration(seconds: 2));

    if (authService.isLoggedIn) {
      final user = authService.currentUser;

      // Super admin → panel khusus (tidak perlu cek subscription)
      if (user?.isSuperAdmin == true) {
        Get.offAllNamed('/super-admin');
        return;
      }

      // Cek subscription — jika expired/suspended → halaman terkunci
      final sub = authService.subscription;
      if (sub != null && !sub.canAccess) {
        Get.offAllNamed('/subscription-expired');
        return;
      }

      // Cashier selalu bypass branch selection
      final isCashier = user?.isCashier == true;

      if (authService.selectedBranch != null ||
          authService.branches.isEmpty ||
          isCashier) {
        Get.offAllNamed('/dashboard');
      } else {
        Get.offAllNamed('/branch-selection');
      }
    } else {
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo horizontal persis seperti referensi (navy + oranye di bg putih)
            const PayzenLogo.horizontal(size: 72),
            SizedBox(height: 10.h),
            Text(
              'POS & Payment Solution',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF1E2A5E).withValues(alpha: 0.45),
                letterSpacing: 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 52.h),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Color(0xFFE8460A),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}