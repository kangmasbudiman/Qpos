<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Stock;
use App\Models\StockMovement;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class StockController extends Controller
{
    /**
     * Get stock list for a branch
     */
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;
        $branchId = $request->branch_id ?? $request->user()->branch_id;

        if (!$branchId) {
            return response()->json([
                'success' => false,
                'message' => 'Branch ID is required'
            ], 422);
        }

        $stocks = Stock::where('branch_id', $branchId)
            ->whereHas('product', function ($query) use ($merchantId) {
                $query->where('merchant_id', $merchantId);
            })
            ->when($request->search, function ($query, $search) {
                $query->whereHas('product', function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                      ->orWhere('sku', 'like', "%{$search}%");
                });
            })
            ->when($request->low_stock, function ($query) {
                $query->whereHas('product', function ($q) {
                    $q->whereColumn('stocks.quantity', '<=', 'products.min_stock');
                });
            })
            ->with(['product.category', 'branch'])
            ->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data' => $stocks
        ]);
    }

    /**
     * Stock adjustment
     */
    public function adjustment(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'branch_id' => 'required|exists:branches,id',
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer',
            'notes' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        DB::beginTransaction();
        try {
            $branchId = $request->branch_id;
            $productId = $request->product_id;

            // Get or create stock
            $stock = Stock::firstOrCreate(
                ['product_id' => $productId, 'branch_id' => $branchId],
                ['quantity' => 0]
            );

            $quantityBefore = $stock->quantity;
            $stock->quantity = $request->quantity;
            
            if ($stock->quantity < 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Stock quantity cannot be negative'
                ], 422);
            }
            
            $stock->save();

            $adjustmentQty = $request->quantity - $quantityBefore;

            // Record stock movement
            StockMovement::create([
                'product_id' => $productId,
                'branch_id' => $branchId,
                'type' => 'adjustment',
                'quantity' => abs($adjustmentQty),
                'quantity_before' => $quantityBefore,
                'quantity_after' => $stock->quantity,
                'notes' => $request->notes ?? 'Manual stock adjustment',
                'user_id' => $request->user()->id,
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Stock adjusted successfully',
                'data' => $stock->load(['product', 'branch'])
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to adjust stock: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Transfer stock between branches
     */
    public function transfer(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'from_branch_id' => 'required|exists:branches,id',
            'to_branch_id' => 'required|exists:branches,id|different:from_branch_id',
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1',
            'notes' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        DB::beginTransaction();
        try {
            $fromBranchId = $request->from_branch_id;
            $toBranchId = $request->to_branch_id;
            $productId = $request->product_id;
            $quantity = $request->quantity;

            // Get from stock
            $fromStock = Stock::where('product_id', $productId)
                ->where('branch_id', $fromBranchId)
                ->first();

            if (!$fromStock || $fromStock->quantity < $quantity) {
                return response()->json([
                    'success' => false,
                    'message' => 'Insufficient stock in source branch'
                ], 422);
            }

            // Get or create to stock
            $toStock = Stock::firstOrCreate(
                ['product_id' => $productId, 'branch_id' => $toBranchId],
                ['quantity' => 0]
            );

            // Update stocks
            $fromQuantityBefore = $fromStock->quantity;
            $fromStock->quantity -= $quantity;
            $fromStock->save();

            $toQuantityBefore = $toStock->quantity;
            $toStock->quantity += $quantity;
            $toStock->save();

            // Record stock movements
            // Out from source branch
            StockMovement::create([
                'product_id' => $productId,
                'branch_id' => $fromBranchId,
                'type' => 'transfer',
                'quantity' => $quantity,
                'quantity_before' => $fromQuantityBefore,
                'quantity_after' => $fromStock->quantity,
                'from_branch_id' => $fromBranchId,
                'to_branch_id' => $toBranchId,
                'notes' => $request->notes ?? 'Stock transfer',
                'user_id' => $request->user()->id,
            ]);

            // In to destination branch
            StockMovement::create([
                'product_id' => $productId,
                'branch_id' => $toBranchId,
                'type' => 'transfer',
                'quantity' => $quantity,
                'quantity_before' => $toQuantityBefore,
                'quantity_after' => $toStock->quantity,
                'from_branch_id' => $fromBranchId,
                'to_branch_id' => $toBranchId,
                'notes' => $request->notes ?? 'Stock transfer',
                'user_id' => $request->user()->id,
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Stock transferred successfully',
                'data' => [
                    'from_stock' => $fromStock->load(['product', 'branch']),
                    'to_stock' => $toStock->load(['product', 'branch']),
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to transfer stock: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get stock movement history
     */
    public function movements(Request $request)
    {
        $merchantId = $request->user()->merchant_id;

        $movements = StockMovement::whereHas('product', function ($query) use ($merchantId) {
                $query->where('merchant_id', $merchantId);
            })
            ->when($request->branch_id, function ($query, $branchId) {
                $query->where('branch_id', $branchId);
            })
            ->when($request->product_id, function ($query, $productId) {
                $query->where('product_id', $productId);
            })
            ->when($request->type, function ($query, $type) {
                $query->where('type', $type);
            })
            ->when($request->date_from, function ($query, $dateFrom) {
                $query->whereDate('created_at', '>=', $dateFrom);
            })
            ->when($request->date_to, function ($query, $dateTo) {
                $query->whereDate('created_at', '<=', $dateTo);
            })
            ->with(['product', 'branch', 'user', 'fromBranch', 'toBranch'])
            ->latest()
            ->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data' => $movements
        ]);
    }
}
