<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\Stock;
use App\Models\StockMovement;
use App\Models\Customer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class SaleController extends Controller
{
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;
        
        $sales = Sale::where('merchant_id', $merchantId)
            ->when($request->branch_id, function ($query, $branchId) {
                $query->where('branch_id', $branchId);
            })
            ->when($request->user()->branch_id && !$request->has('branch_id'), function ($query) use ($request) {
                // If user has branch_id, filter by their branch
                $query->where('branch_id', $request->user()->branch_id);
            })
            ->when($request->status, function ($query, $status) {
                $query->where('status', $status);
            })
            ->when($request->customer_id, function ($query, $customerId) {
                $query->where('customer_id', $customerId);
            })
            ->when($request->date_from, function ($query, $dateFrom) {
                $query->whereDate('created_at', '>=', $dateFrom);
            })
            ->when($request->date_to, function ($query, $dateTo) {
                $query->whereDate('created_at', '<=', $dateTo);
            })
            ->with(['customer', 'branch', 'user'])
            ->latest()
            ->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data' => $sales
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'branch_id' => 'required|exists:branches,id',
            'customer_id' => 'nullable|exists:customers,id',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.price' => 'required|numeric|min:0',
            'items.*.discount' => 'nullable|numeric|min:0',
            'discount' => 'nullable|numeric|min:0',
            'tax' => 'nullable|numeric|min:0',
            'paid' => 'required|numeric|min:0',
            'payment_method' => 'required|in:cash,card,transfer,ewallet',
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
                $itemSubtotal = ($item['price'] * $item['quantity']) - ($item['discount'] ?? 0);
                $subtotal += $itemSubtotal;
            }

            $discount = $request->discount ?? 0;
            $tax = $request->tax ?? 0;
            $total = $subtotal - $discount + $tax;
            $paid = $request->paid;
            $change = $paid - $total;

            if ($change < 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Insufficient payment'
                ], 422);
            }

            // Generate invoice number
            $invoiceNumber = 'INV-' . date('Ymd') . '-' . str_pad(Sale::whereDate('created_at', today())->count() + 1, 4, '0', STR_PAD_LEFT);

            // Create sale
            $sale = Sale::create([
                'invoice_number' => $invoiceNumber,
                'merchant_id' => $merchantId,
                'branch_id' => $branchId,
                'customer_id' => $request->customer_id,
                'user_id' => $request->user()->id,
                'subtotal' => $subtotal,
                'discount' => $discount,
                'tax' => $tax,
                'total' => $total,
                'paid' => $paid,
                'change' => $change,
                'payment_method' => $request->payment_method,
                'status' => 'completed',
                'notes' => $request->notes,
            ]);

            // Create sale items and update stock
            foreach ($request->items as $item) {
                $product = \App\Models\Product::find($item['product_id']);
                
                // Create sale item
                $itemSubtotal = ($item['price'] * $item['quantity']) - ($item['discount'] ?? 0);
                SaleItem::create([
                    'sale_id' => $sale->id,
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'price' => $item['price'],
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
                $stock->quantity -= $item['quantity'];
                
                if ($stock->quantity < 0) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Insufficient stock for product: {$product->name}"
                    ], 422);
                }
                
                $stock->save();

                // Record stock movement
                StockMovement::create([
                    'product_id' => $product->id,
                    'branch_id' => $branchId,
                    'type' => 'out',
                    'quantity' => $item['quantity'],
                    'quantity_before' => $quantityBefore,
                    'quantity_after' => $stock->quantity,
                    'reference_type' => 'Sale',
                    'reference_id' => $sale->id,
                    'user_id' => $request->user()->id,
                ]);
            }

            // Update customer stats
            if ($request->customer_id) {
                $customer = Customer::find($request->customer_id);
                $customer->increment('total_transactions');
                $customer->increment('total_spent', $total);
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Sale created successfully',
                'data' => $sale->load(['items.product', 'customer', 'branch'])
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to create sale: ' . $e->getMessage()
            ], 500);
        }
    }

    public function show(Request $request, $id)
    {
        $sale = Sale::where('merchant_id', $request->user()->merchant_id)
            ->with(['items.product', 'customer', 'branch', 'user'])
            ->find($id);

        if (!$sale) {
            return response()->json([
                'success' => false,
                'message' => 'Sale not found'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $sale
        ]);
    }

    public function cancel(Request $request, $id)
    {
        $sale = Sale::where('merchant_id', $request->user()->merchant_id)->find($id);

        if (!$sale) {
            return response()->json([
                'success' => false,
                'message' => 'Sale not found'
            ], 404);
        }

        if ($sale->status === 'cancelled') {
            return response()->json([
                'success' => false,
                'message' => 'Sale already cancelled'
            ], 422);
        }

        DB::beginTransaction();
        try {
            // Restore stock
            foreach ($sale->items as $item) {
                $stock = Stock::where('product_id', $item->product_id)
                    ->where('branch_id', $sale->branch_id)
                    ->first();

                if ($stock) {
                    $quantityBefore = $stock->quantity;
                    $stock->quantity += $item->quantity;
                    $stock->save();

                    // Record stock movement
                    StockMovement::create([
                        'product_id' => $item->product_id,
                        'branch_id' => $sale->branch_id,
                        'type' => 'in',
                        'quantity' => $item->quantity,
                        'quantity_before' => $quantityBefore,
                        'quantity_after' => $stock->quantity,
                        'reference_type' => 'Sale',
                        'reference_id' => $sale->id,
                        'notes' => 'Sale cancellation',
                        'user_id' => $request->user()->id,
                    ]);
                }
            }

            // Update customer stats
            if ($sale->customer_id) {
                $customer = Customer::find($sale->customer_id);
                $customer->decrement('total_transactions');
                $customer->decrement('total_spent', $sale->total);
            }

            $sale->update(['status' => 'cancelled']);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Sale cancelled successfully',
                'data' => $sale
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to cancel sale: ' . $e->getMessage()
            ], 500);
        }
    }
}
