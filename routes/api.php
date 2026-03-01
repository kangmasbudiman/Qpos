<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\SaleController;
use App\Http\Controllers\Api\PurchaseController;
use App\Http\Controllers\Api\StockController;
use App\Http\Controllers\Api\UploadController;
use App\Http\Controllers\Api\StaffController;
use App\Http\Controllers\Api\ProfitLossController;
use App\Http\Controllers\Api\StockOpnameController;
use App\Http\Controllers\Api\BackupController;
use App\Http\Controllers\Api\RegistrationController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\AppSettingController;
use App\Http\Controllers\DisplayController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Customer Display — polling JSON (tanpa auth, bisa diakses browser)
Route::get('display/{branchId}', [DisplayController::class, 'poll'])
    ->where('branchId', '[0-9]+');

// Public settings (harga langganan — untuk Flutter layar expired)
Route::get('settings/public', [AppSettingController::class, 'public']);

// Public routes
Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('check-registration', [AuthController::class, 'checkRegistrationStatus']);
    Route::post('lookup-company', [AuthController::class, 'lookupCompany']);
    Route::post('login', [AuthController::class, 'login']);
    Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
});

// Protected routes
Route::middleware('auth:sanctum')->group(function () {

    // Auth routes (tidak kena subscription check — perlu untuk cek status)
    Route::prefix('auth')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('profile', [AuthController::class, 'profile']);
        Route::put('profile', [AuthController::class, 'updateProfile']);
        Route::post('change-password', [AuthController::class, 'changePassword']);
        Route::get('branches', [AuthController::class, 'branches']);
        Route::get('subscription', [SubscriptionController::class, 'status']); // cek status tanpa block
    });

    // Semua route di bawah ini kena subscription check
    Route::middleware('subscription')->group(function () {

    // Categories
    Route::apiResource('categories', CategoryController::class);

    // Branches
    Route::apiResource('branches', BranchController::class);

    // Staff management (owner/manager only)
    Route::prefix('staff')->group(function () {
        Route::get('/', [StaffController::class, 'index']);
        Route::post('/', [StaffController::class, 'store']);
        Route::get('{id}', [StaffController::class, 'show']);
        Route::put('{id}', [StaffController::class, 'update']);
        Route::delete('{id}', [StaffController::class, 'destroy']);
        Route::post('{id}/toggle-active', [StaffController::class, 'toggleActive']);
    });
    Route::get('branches/{branchId}/categories', [CategoryController::class, 'byBranch']);

    // Products
    Route::apiResource('products', ProductController::class);
    Route::get('products/{id}/stock', [ProductController::class, 'getStock']);

    // Suppliers
    Route::apiResource('suppliers', SupplierController::class);

    // Customers
    Route::apiResource('customers', CustomerController::class);

    // Sales
    Route::prefix('sales')->group(function () {
        Route::get('/', [SaleController::class, 'index']);
        Route::post('/', [SaleController::class, 'store']);
        Route::get('{id}', [SaleController::class, 'show']);
        Route::post('{id}/cancel', [SaleController::class, 'cancel']);
    });

    // Purchases
    Route::prefix('purchases')->group(function () {
        Route::get('/', [PurchaseController::class, 'index']);
        Route::post('/', [PurchaseController::class, 'store']);
        Route::get('{id}', [PurchaseController::class, 'show']);
        Route::post('{id}/cancel', [PurchaseController::class, 'cancel']);
    });

    // Image Upload
    Route::prefix('upload')->group(function () {
        Route::post('image', [UploadController::class, 'uploadImage']);
        Route::delete('image', [UploadController::class, 'deleteImage']);
    });

    // Reports
    Route::get('reports/profit-loss', [ProfitLossController::class, 'index']);

    // Backup
    Route::get('backup/download', [BackupController::class, 'download']);
    Route::post('backup/restore', [BackupController::class, 'restore']);

    // Registration Management (super_admin only - untuk Owner App)
    Route::middleware('super_admin')->prefix('registrations')->group(function () {
        Route::get('/', [RegistrationController::class, 'index']);
        Route::get('stats', [RegistrationController::class, 'stats']);
        Route::get('{id}', [RegistrationController::class, 'show']);
        Route::post('{id}/approve', [RegistrationController::class, 'approve']);
        Route::post('{id}/reject', [RegistrationController::class, 'reject']);
        Route::post('{id}/resend-code', [RegistrationController::class, 'resendCode']);
    });

    // Stock Management
    Route::prefix('stocks')->group(function () {
        Route::get('/', [StockController::class, 'index']);
        Route::post('adjustment', [StockController::class, 'adjustment']);
        Route::post('transfer', [StockController::class, 'transfer']);
        Route::get('movements', [StockController::class, 'movements']);
    });

    // Customer Display — push cart dari Flutter kasir
    Route::post('display/update', [DisplayController::class, 'update']);

    // Stock Opname
    Route::prefix('stock-opnames')->group(function () {
        Route::get('/', [StockOpnameController::class, 'index']);
        Route::post('/', [StockOpnameController::class, 'store']);
        Route::get('{stockOpname}', [StockOpnameController::class, 'show']);
    });

    }); // end middleware('subscription')

    // Super Admin — kelola app settings (harga, trial days, support contact)
    Route::middleware('super_admin')->prefix('settings')->group(function () {
        Route::get('/', [AppSettingController::class, 'index']);
        Route::put('/', [AppSettingController::class, 'update']);
    });

    // Super Admin — kelola subscription merchant
    Route::middleware('super_admin')->prefix('subscriptions')->group(function () {
        Route::get('/', [SubscriptionController::class, 'index']);
        Route::post('{merchantId}/activate', [SubscriptionController::class, 'activate']);
        Route::post('{merchantId}/extend', [SubscriptionController::class, 'extend']);
        Route::post('{merchantId}/suspend', [SubscriptionController::class, 'suspend']);
        Route::post('{merchantId}/reset-trial', [SubscriptionController::class, 'resetTrial']);
        Route::post('{merchantId}/change-tier', [SubscriptionController::class, 'changeTier']);
    });
});
