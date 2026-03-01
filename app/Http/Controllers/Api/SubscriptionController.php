<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Merchant;
use App\Models\AppSetting;
use Illuminate\Http\Request;

class SubscriptionController extends Controller
{
    /** Status subscription milik user yang login (Flutter app) */
    public function status(Request $request)
    {
        $user = $request->user();
        if (!$user->merchant_id) {
            return response()->json(['success' => false, 'message' => 'No merchant'], 404);
        }

        $merchant = Merchant::find($user->merchant_id);
        if (!$merchant) {
            return response()->json(['success' => false, 'message' => 'Merchant not found'], 404);
        }

        return response()->json([
            'success'      => true,
            'subscription' => $merchant->subscriptionInfo(),
            'pricing'      => [
                'price_monthly'          => AppSetting::priceMonthly(),
                'price_yearly'           => AppSetting::priceYearly(),
                'price_starter_monthly'  => AppSetting::priceStarterMonthly(),
                'price_starter_yearly'   => AppSetting::priceStarterYearly(),
                'price_business_monthly' => AppSetting::priceBusinessMonthly(),
                'price_business_yearly'  => AppSetting::priceBusinessYearly(),
                'trial_days'             => AppSetting::trialDays(),
                'support_email'          => AppSetting::get('support_email', 'support@payzen.id'),
                'support_whatsapp'       => AppSetting::get('support_whatsapp', ''),
            ],
        ]);
    }

    /** List semua merchant + status subscription (Super Admin) */
    public function index(Request $request)
    {
        $merchants = Merchant::where('registration_status', 'approved')
            ->select('id', 'name', 'company_code', 'email', 'phone',
                     'subscription_status', 'trial_ends_at', 'subscription_ends_at',
                     'plan_type', 'last_payment_at', 'last_payment_amount', 'approved_at')
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn($m) => [
                'id'            => $m->id,
                'name'          => $m->name,
                'company_code'  => $m->company_code,
                'email'         => $m->email,
                'phone'         => $m->phone,
                'subscription'  => $m->subscriptionInfo(),
                'approved_at'   => $m->approved_at?->toDateString(),
            ]);

        return response()->json(['success' => true, 'data' => $merchants]);
    }

    /**
     * Aktifkan langganan berbayar.
     * Body: { plan_type: 'monthly'|'yearly', amount?: 99000 }
     * Jika amount tidak dikirim, pakai harga dari AppSetting.
     */
    public function activate(Request $request, $merchantId)
    {
        $request->validate([
            'plan_type' => 'required|in:monthly,yearly',
            'amount'    => 'sometimes|numeric|min:0',
            'tier'      => 'sometimes|in:starter,business',
        ]);

        $merchant = Merchant::findOrFail($merchantId);
        $tier     = $request->input('tier', $merchant->subscription_tier ?? 'starter');

        $months = $request->plan_type === 'yearly' ? 12 : 1;
        $endsAt = now()->addMonths($months);

        // Gunakan amount dari request, atau fallback ke harga tier dari setting
        if ($request->filled('amount')) {
            $amount = $request->amount;
        } elseif ($tier === 'business') {
            $amount = $request->plan_type === 'yearly'
                ? AppSetting::priceBusinessYearly()
                : AppSetting::priceBusinessMonthly();
        } else {
            $amount = $request->plan_type === 'yearly'
                ? AppSetting::priceStarterYearly()
                : AppSetting::priceStarterMonthly();
        }

        $merchant->update([
            'subscription_status'  => 'active',
            'subscription_ends_at' => $endsAt,
            'plan_type'            => $request->plan_type,
            'subscription_tier'    => $tier,
            'last_payment_at'      => now(),
            'last_payment_amount'  => $amount,
        ]);

        return response()->json([
            'success' => true,
            'message' => "Langganan {$request->plan_type} diaktifkan hingga {$endsAt->toDateString()}",
            'subscription' => $merchant->subscriptionInfo(),
        ]);
    }

    /**
     * Perpanjang langganan yang sudah ada.
     * Body: { plan_type: 'monthly'|'yearly', amount?: 99000, tier?: 'starter'|'business' }
     */
    public function extend(Request $request, $merchantId)
    {
        $request->validate([
            'plan_type' => 'required|in:monthly,yearly',
            'amount'    => 'sometimes|numeric|min:0',
            'tier'      => 'sometimes|in:starter,business',
        ]);

        $merchant = Merchant::findOrFail($merchantId);
        $months   = $request->plan_type === 'yearly' ? 12 : 1;
        $tier     = $request->input('tier', $merchant->subscription_tier ?? 'starter');

        if ($request->filled('amount')) {
            $amount = $request->amount;
        } elseif ($tier === 'business') {
            $amount = $request->plan_type === 'yearly'
                ? AppSetting::priceBusinessYearly()
                : AppSetting::priceBusinessMonthly();
        } else {
            $amount = $request->plan_type === 'yearly'
                ? AppSetting::priceStarterYearly()
                : AppSetting::priceStarterMonthly();
        }

        // Jika masih aktif, perpanjang dari tanggal berakhir. Jika expired, dari sekarang.
        $base   = ($merchant->subscription_ends_at && $merchant->subscription_ends_at->isFuture())
                  ? $merchant->subscription_ends_at
                  : now();
        $endsAt = $base->addMonths($months);

        $merchant->update([
            'subscription_status'  => 'active',
            'subscription_ends_at' => $endsAt,
            'plan_type'            => $request->plan_type,
            'subscription_tier'    => $tier,
            'last_payment_at'      => now(),
            'last_payment_amount'  => $amount,
        ]);

        return response()->json([
            'success' => true,
            'message' => "Langganan diperpanjang hingga {$endsAt->toDateString()}",
            'subscription' => $merchant->subscriptionInfo(),
        ]);
    }

    /**
     * Ganti tier subscription merchant (tanpa mengubah status/tanggal).
     * Body: { tier: 'starter'|'business' }
     */
    public function changeTier(Request $request, $merchantId)
    {
        $request->validate(['tier' => 'required|in:starter,business']);

        $merchant = Merchant::findOrFail($merchantId);
        $merchant->update(['subscription_tier' => $request->tier]);

        return response()->json([
            'success'      => true,
            'message'      => "Tier berhasil diganti ke {$request->tier}",
            'subscription' => $merchant->subscriptionInfo(),
        ]);
    }

    /** Suspend akun merchant */
    public function suspend(Request $request, $merchantId)
    {
        $merchant = Merchant::findOrFail($merchantId);
        $merchant->update(['subscription_status' => 'suspended']);

        return response()->json([
            'success' => true,
            'message' => 'Merchant telah di-suspend',
        ]);
    }

    /** Reset trial (tambah 7 hari trial lagi — untuk promo/testing) */
    public function resetTrial(Request $request, $merchantId)
    {
        $merchant = Merchant::findOrFail($merchantId);
        $days = AppSetting::trialDays();
        $merchant->update([
            'subscription_status' => 'trial',
            'trial_ends_at'       => now()->addDays($days),
        ]);

        return response()->json([
            'success' => true,
            'message' => "Trial direset {$days} hari dari sekarang",
            'subscription' => $merchant->subscriptionInfo(),
        ]);
    }
}
