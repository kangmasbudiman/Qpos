<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class DisplayController extends Controller
{
    /**
     * API: Kasir push data cart ke cache (dipanggil dari Flutter)
     * POST /api/display/update
     */
    public function update(Request $request)
    {
        $validated = $request->validate([
            'branch_id'  => 'required|integer',
            'store_name' => 'nullable|string|max:255',
            'items'      => 'nullable|array',
            'total'      => 'nullable|numeric',
        ]);

        $branchId = $validated['branch_id'];
        $key      = "display_{$branchId}";

        $data = [
            'store_name' => $validated['store_name'] ?? 'Toko',
            'items'      => $validated['items'] ?? [],
            'total'      => $validated['total'] ?? 0,
            'updated_at' => now()->toIso8601String(),
        ];

        // Simpan ke cache 10 menit (auto-clear jika kasir tidak aktif)
        Cache::put($key, $data, now()->addMinutes(10));

        return response()->json(['success' => true]);
    }

    /**
     * Web: Halaman customer display (browser)
     * GET /display/{branchId}
     */
    public function show(int $branchId)
    {
        $key  = "display_{$branchId}";
        $data = Cache::get($key, [
            'store_name' => 'PAYZEN',
            'items'      => [],
            'total'      => 0,
            'updated_at' => null,
        ]);

        return view('display', [
            'branchId'  => $branchId,
            'storeName' => $data['store_name'] ?? 'PAYZEN',
            'items'     => $data['items'] ?? [],
            'total'     => $data['total'] ?? 0,
            'updatedAt' => $data['updated_at'],
        ]);
    }

    /**
     * API: Polling JSON untuk auto-refresh di browser (dipanggil oleh JS)
     * GET /api/display/{branchId}
     */
    public function poll(int $branchId)
    {
        $key  = "display_{$branchId}";
        $data = Cache::get($key, [
            'store_name' => 'PAYZEN',
            'items'      => [],
            'total'      => 0,
            'updated_at' => null,
        ]);

        return response()->json($data);
    }
}
