<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DisplayController;

Route::get('/', function () {
    return view('welcome');
});

// Customer Display — tanpa auth, akses publik via browser
Route::get('/display/{branchId}', [DisplayController::class, 'show'])
    ->where('branchId', '[0-9]+');
