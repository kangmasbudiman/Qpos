<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Stock;
use App\Models\StockMovement;
use App\Models\StockOpname;
use App\Models\StockOpnameItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class StockOpnameController extends Controller
{
    /**
     * List semua opname (history)
     */
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;
        $branchId   = $request->branch_id ?? $request->user()->branch_id;

        $opnames = StockOpname::where('merchant_id', $merchantId)
            ->when($branchId, fn($q) => $q->where('branch_id', $branchId))
            ->with(['branch', 'user'])
            ->latest()
            ->paginate($request->per_page ?? 15);

        return response()->json(['success' => true, 'data' => $opnames]);
    }

    /**
     * Detail satu opname beserta item-itemnya
     */
    public function show(StockOpname $stockOpname)
    {
        $stockOpname->load(['branch', 'user', 'items.product']);

        return response()->json(['success' => true, 'data' => $stockOpname]);
    }

    /**
     * Simpan opname baru (status draft / langsung complete)
     *
     * Body JSON:
     * {
     *   "branch_id": 1,
     *   "opname_date": "2026-02-24",
     *   "notes": "...",
     *   "items": [
     *     { "product_id": 5, "counted_qty": 10 },
     *     ...
     *   ]
     * }
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'branch_id'              => 'required|exists:branches,id',
            'opname_date'            => 'required|date',
            'notes'                  => 'nullable|string',
            'items'                  => 'required|array|min:1',
            'items.*.product_id'     => 'required|exists:products,id',
            'items.*.counted_qty'    => 'required|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors(),
            ], 422);
        }

        DB::beginTransaction();
        try {
            $merchantId = $request->user()->merchant_id;
            $branchId   = $request->branch_id;

            // Generate nomor opname
            $count         = StockOpname::where('merchant_id', $merchantId)->count() + 1;
            $opnameNumber  = 'OPN-' . now()->format('Ymd') . '-' . str_pad($count, 4, '0', STR_PAD_LEFT);

            $opname = StockOpname::create([
                'opname_number' => $opnameNumber,
                'merchant_id'   => $merchantId,
                'branch_id'     => $branchId,
                'user_id'       => $request->user()->id,
                'opname_date'   => $request->opname_date,
                'status'        => 'completed',
                'notes'         => $request->notes,
            ]);

            foreach ($request->items as $item) {
                $productId  = $item['product_id'];
                $countedQty = (int) $item['counted_qty'];

                // Ambil stok sistem saat ini
                $stock     = Stock::firstOrCreate(
                    ['product_id' => $productId, 'branch_id' => $branchId],
                    ['quantity' => 0]
                );
                $systemQty = $stock->quantity;
                $variance  = $countedQty - $systemQty;

                // Simpan item opname
                StockOpnameItem::create([
                    'stock_opname_id' => $opname->id,
                    'product_id'      => $productId,
                    'system_qty'      => $systemQty,
                    'counted_qty'     => $countedQty,
                    'variance'        => $variance,
                    'notes'           => $item['notes'] ?? null,
                ]);

                // Jika ada selisih → sesuaikan stok & catat movement
                if ($variance !== 0) {
                    $stock->quantity = $countedQty;
                    $stock->save();

                    StockMovement::create([
                        'product_id'     => $productId,
                        'branch_id'      => $branchId,
                        'type'           => 'adjustment',
                        'quantity'       => abs($variance),
                        'quantity_before'=> $systemQty,
                        'quantity_after' => $countedQty,
                        'reference_type' => 'StockOpname',
                        'reference_id'   => $opname->id,
                        'notes'          => 'Stock opname: ' . $opnameNumber,
                        'user_id'        => $request->user()->id,
                    ]);
                }
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Stock opname berhasil disimpan',
                'data'    => $opname->load(['branch', 'user', 'items.product']),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal menyimpan opname: ' . $e->getMessage(),
            ], 500);
        }
    }
}
