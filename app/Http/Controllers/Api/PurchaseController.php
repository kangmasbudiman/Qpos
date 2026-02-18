<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Purchase;
use App\Models\PurchaseItem;
use App\Models\Stock;
use App\Models\StockMovement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class PurchaseController extends Controller
{
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;
        
        $purchases = Purchase::where('merchant_id', $merchantId)
            ->when($request->branch_id, function ($query, $branchId) {
                $query->where('branch_id', $branchId);
            })
            ->when($request->user()->branch_id && !$request->has('branch_id'), function ($query) use ($request) {
                $query->where('branch_id', $request->user()->branch_id);
            })
            ->when($request->status, function ($query, $status) {
                $query->where('status', $status);
            })
            ->when($request->supplier_id, function ($query, $supplierId) {
                $query->where('supplier_id', $supplierId);
            })
            ->when($request->date_from, function ($query, $dateFrom) {
                $query->whereDate('purchase_date', '>=', $dateFrom);
            })
            ->when($request->date_to, function ($query, $dateTo) {
                $query->whereDate('purchase_date', '<=', $dateTo);
            })
            ->with(['supplier', 'branch', 'user'])
            ->latest()
            ->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data' => $purchases
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'branch_id' => 'required|exists:branches,id',
            'supplier_id' => 'nullable|exists:suppliers,id',
            'purchase_date' => 'required|date',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.cost' => 'required|numeric|min:0',
            'items.*.discount' => 'nullable|numeric|min:0',
            'discount' => 'nullable|numeric|min:0',
            'tax' => 'nullable|numeric|min:0',
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
            $merchantId = $request->user()->merchant_id;
            $branchId = $request->branch_id;

            // Calculate totals
            $subtotal = 0;
            foreach ($request->items as $item) {
                $itemSubtotal = ($item['cost'] * $item['quantity']) - ($item['discount'] ?? 0);
                $subtotal += $itemSubtotal;
            }

            $discount = $request->discount ?? 0;
            $tax = $request->tax ?? 0;
            $total = $subtotal - $discount + $tax;

            // Generate purchase number
            $purchaseNumber = 'PO-' . date('Ymd') . '-' . str_pad(Purchase::whereDate('created_at', today())->count() + 1, 4, '0', STR_PAD_LEFT);

            // Create purchase
            $purchase = Purchase::create([
                'purchase_number' => $purchaseNumber,
                'merchant_id' => $merchantId,
                'branch_id' => $branchId,
                'supplier_id' => $request->supplier_id,
                'user_id' => $request->user()->id,
                'purchase_date' => $request->purchase_date,
                'subtotal' => $subtotal,
                'discount' => $discount,
                'tax' => $tax,
                'total' => $total,
                'status' => 'received',
                'notes' => $request->notes,
            ]);

            // Create purchase items and update stock
            foreach ($request->items as $item) {
                $product = \App\Models\Product::find($item['product_id']);
                
                // Create purchase item
                $itemSubtotal = ($item['cost'] * $item['quantity']) - ($item['discount'] ?? 0);
                PurchaseItem::create([
                    'purchase_id' => $purchase->id,
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'cost' => $item['cost'],
                    'quantity' => $item['quantity'],
                    'discount' => $item['discount'] ?? 0,
                    'subtotal' => $itemSubtotal,
                ]);

                // Update stock
                $stock = Stock::firstOrCreate(
                    ['product_id' => $product->id, 'branch_id' => $branchId],
                    ['quantity' => 0]
                );

                $quantityBefore = $stock->quantity;
                $stock->quantity += $item['quantity'];
                $stock->save();

                // Record stock movement
                StockMovement::create([
                    'product_id' => $product->id,
                    'branch_id' => $branchId,
                    'type' => 'in',
                    'quantity' => $item['quantity'],
                    'quantity_before' => $quantityBefore,
                    'quantity_after' => $stock->quantity,
                    'reference_type' => 'Purchase',
                    'reference_id' => $purchase->id,
                    'user_id' => $request->user()->id,
                ]);
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Purchase created successfully',
                'data' => $purchase->load(['items.product', 'supplier', 'branch'])
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to create purchase: ' . $e->getMessage()
            ], 500);
        }
    }

    public function show(Request $request, $id)
    {
        $purchase = Purchase::where('merchant_id', $request->user()->merchant_id)
            ->with(['items.product', 'supplier', 'branch', 'user'])
            ->find($id);

        if (!$purchase) {
            return response()->json([
                'success' => false,
                'message' => 'Purchase not found'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $purchase
        ]);
    }

    public function cancel(Request $request, $id)
    {
        $purchase = Purchase::where('merchant_id', $request->user()->merchant_id)->find($id);

        if (!$purchase) {
            return response()->json([
                'success' => false,
                'message' => 'Purchase not found'
            ], 404);
        }

        if ($purchase->status === 'cancelled') {
            return response()->json([
                'success' => false,
                'message' => 'Purchase already cancelled'
            ], 422);
        }

        DB::beginTransaction();
        try {
            // Reduce stock
            foreach ($purchase->items as $item) {
                $stock = Stock::where('product_id', $item->product_id)
                    ->where('branch_id', $purchase->branch_id)
                    ->first();

                if ($stock) {
                    $quantityBefore = $stock->quantity;
                    $stock->quantity -= $item->quantity;
                    
                    if ($stock->quantity < 0) {
                        DB::rollBack();
                        return response()->json([
                            'success' => false,
                            'message' => 'Cannot cancel: insufficient stock'
                        ], 422);
                    }
                    
                    $stock->save();

                    // Record stock movement
                    StockMovement::create([
                        'product_id' => $item->product_id,
                        'branch_id' => $purchase->branch_id,
                        'type' => 'out',
                        'quantity' => $item->quantity,
                        'quantity_before' => $quantityBefore,
                        'quantity_after' => $stock->quantity,
                        'reference_type' => 'Purchase',
                        'reference_id' => $purchase->id,
                        'notes' => 'Purchase cancellation',
                        'user_id' => $request->user()->id,
                    ]);
                }
            }

            $purchase->update(['status' => 'cancelled']);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Purchase cancelled successfully',
                'data' => $purchase
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to cancel purchase: ' . $e->getMessage()
            ], 500);
        }
    }
}
