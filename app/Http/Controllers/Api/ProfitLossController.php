<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Sale;
use App\Models\Purchase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProfitLossController extends Controller
{
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;
        $dateFrom   = $request->date_from ?? now()->startOfMonth()->toDateString();
        $dateTo     = $request->date_to   ?? now()->toDateString();
        $branchId   = $request->branch_id;

        // ── PENJUALAN ────────────────────────────────────────────────────────
        $salesQuery = Sale::where('merchant_id', $merchantId)
            ->where('status', 'completed')
            ->whereDate('created_at', '>=', $dateFrom)
            ->whereDate('created_at', '<=', $dateTo);

        if ($branchId) {
            $salesQuery->where('branch_id', $branchId);
        } elseif ($request->user()->branch_id) {
            $salesQuery->where('branch_id', $request->user()->branch_id);
        }

        $salesAgg = $salesQuery->selectRaw(
            'COUNT(*) as total_transactions,
             SUM(subtotal) as gross_sales,
             SUM(discount) as total_discount,
             SUM(tax) as total_tax,
             SUM(total) as net_sales'
        )->first();

        // ── HPP (Harga Pokok Penjualan) ───────────────────────────────────
        // HPP = SUM(sale_items.quantity × products.cost)
        $hppQuery = DB::table('sale_items')
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->where('sales.merchant_id', $merchantId)
            ->where('sales.status', 'completed')
            ->whereDate('sales.created_at', '>=', $dateFrom)
            ->whereDate('sales.created_at', '<=', $dateTo);

        if ($branchId) {
            $hppQuery->where('sales.branch_id', $branchId);
        } elseif ($request->user()->branch_id) {
            $hppQuery->where('sales.branch_id', $request->user()->branch_id);
        }

        $hpp = $hppQuery->sum(DB::raw('sale_items.quantity * products.cost'));

        // ── PEMBELIAN STOK (Beban Operasional) ───────────────────────────
        $purchaseQuery = Purchase::where('merchant_id', $merchantId)
            ->where('status', 'received')
            ->whereDate('purchase_date', '>=', $dateFrom)
            ->whereDate('purchase_date', '<=', $dateTo);

        if ($branchId) {
            $purchaseQuery->where('branch_id', $branchId);
        } elseif ($request->user()->branch_id) {
            $purchaseQuery->where('branch_id', $request->user()->branch_id);
        }

        $purchaseAgg = $purchaseQuery->selectRaw(
            'COUNT(*) as total_purchases,
             SUM(total) as total_purchase_amount'
        )->first();

        // ── KALKULASI LABA ────────────────────────────────────────────────
        $grossSales      = (float) ($salesAgg->gross_sales ?? 0);
        $totalDiscount   = (float) ($salesAgg->total_discount ?? 0);
        $totalTax        = (float) ($salesAgg->total_tax ?? 0);
        $netSales        = (float) ($salesAgg->net_sales ?? 0);
        $totalHpp        = (float) $hpp;
        $grossProfit     = $netSales - $totalHpp;
        $totalPurchases  = (float) ($purchaseAgg->total_purchase_amount ?? 0);
        $netProfit       = $grossProfit;   // bisa dikurangi biaya lain jika ada

        // ── DATA PER HARI (untuk grafik) ─────────────────────────────────
        $dailyQuery = Sale::where('merchant_id', $merchantId)
            ->where('status', 'completed')
            ->whereDate('created_at', '>=', $dateFrom)
            ->whereDate('created_at', '<=', $dateTo)
            ->selectRaw('DATE(created_at) as date, SUM(total) as revenue, COUNT(*) as transactions');

        if ($branchId) {
            $dailyQuery->where('branch_id', $branchId);
        } elseif ($request->user()->branch_id) {
            $dailyQuery->where('branch_id', $request->user()->branch_id);
        }

        $dailyData = $dailyQuery->groupBy('date')->orderBy('date')->get();

        // ── BREAKDOWN METODE BAYAR ────────────────────────────────────────
        $paymentQuery = Sale::where('merchant_id', $merchantId)
            ->where('status', 'completed')
            ->whereDate('created_at', '>=', $dateFrom)
            ->whereDate('created_at', '<=', $dateTo)
            ->selectRaw('payment_method, SUM(total) as total, COUNT(*) as count');

        if ($branchId) {
            $paymentQuery->where('branch_id', $branchId);
        } elseif ($request->user()->branch_id) {
            $paymentQuery->where('branch_id', $request->user()->branch_id);
        }

        $paymentBreakdown = $paymentQuery->groupBy('payment_method')->get();

        // ── TOP PRODUK ────────────────────────────────────────────────────
        $topProductsQuery = DB::table('sale_items')
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->where('sales.merchant_id', $merchantId)
            ->where('sales.status', 'completed')
            ->whereDate('sales.created_at', '>=', $dateFrom)
            ->whereDate('sales.created_at', '<=', $dateTo)
            ->selectRaw('sale_items.product_name, SUM(sale_items.quantity) as qty, SUM(sale_items.subtotal) as revenue');

        if ($branchId) {
            $topProductsQuery->where('sales.branch_id', $branchId);
        } elseif ($request->user()->branch_id) {
            $topProductsQuery->where('sales.branch_id', $request->user()->branch_id);
        }

        $topProducts = $topProductsQuery
            ->groupBy('sale_items.product_name')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'period' => ['from' => $dateFrom, 'to' => $dateTo],
                'income' => [
                    'gross_sales'         => $grossSales,
                    'total_discount'      => $totalDiscount,
                    'total_tax'           => $totalTax,
                    'net_sales'           => $netSales,
                    'total_transactions'  => (int) ($salesAgg->total_transactions ?? 0),
                ],
                'cogs' => [
                    'hpp'                 => $totalHpp,
                ],
                'expenses' => [
                    'total_purchases'     => $totalPurchases,
                    'total_purchase_count'=> (int) ($purchaseAgg->total_purchases ?? 0),
                ],
                'profit' => [
                    'gross_profit'        => $grossProfit,
                    'gross_margin'        => $netSales > 0 ? round($grossProfit / $netSales * 100, 2) : 0,
                    'net_profit'          => $netProfit,
                    'net_margin'          => $netSales > 0 ? round($netProfit / $netSales * 100, 2) : 0,
                ],
                'daily'            => $dailyData,
                'payment_breakdown'=> $paymentBreakdown,
                'top_products'     => $topProducts,
            ],
        ]);
    }
}
