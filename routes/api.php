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

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Public routes
Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('lookup-company', [AuthController::class, 'lookupCompany']);
    Route::post('login', [AuthController::class, 'login']);
});

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    
    // Auth routes
    Route::prefix('auth')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('profile', [AuthController::class, 'profile']);
        Route::put('profile', [AuthController::class, 'updateProfile']);
        Route::post('change-password', [AuthController::class, 'changePassword']);
    });

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

    // Stock Management
    Route::prefix('stocks')->group(function () {
        Route::get('/', [StockController::class, 'index']);
        Route::post('adjustment', [StockController::class, 'adjustment']);
        Route::post('transfer', [StockController::class, 'transfer']);
        Route::get('movements', [StockController::class, 'movements']);
    });
});
