<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DisplayController;

Route::get('/', function () {
    return view('welcome');
});

// Customer Display — tanpa auth, akses publik via browser
Route::get('/display/{branchId}', [DisplayController::class, 'show'])
    ->where('branchId', '[0-9]+');

// Kebijakan Privasi — publik
Route::get('/privacy-policy', function () {
    return view('privacy_policy');
});

// Dokumentasi — publik
Route::get('/docs', function () {
    return view('docs');
});

Route::get('/docs/{section}', function ($section) {
    return view('docs', ['activeSection' => $section]);
});
