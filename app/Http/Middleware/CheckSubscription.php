<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Models\Merchant;
use Symfony\Component\HttpFoundation\Response;

class CheckSubscription
{
    /**
     * Cek apakah merchant masih dalam masa trial atau subscription aktif.
     * Super admin bypass middleware ini.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        // Super admin selalu bisa akses
        if (!$user || $user->role === 'super_admin') {
            return $next($request);
        }

        // User tanpa merchant (seharusnya tidak terjadi)
        if (!$user->merchant_id) {
            return $next($request);
        }

        $merchant = Merchant::find($user->merchant_id);
        if (!$merchant) {
            return $next($request);
        }

        // Sync status terbaru
        $merchant->syncSubscriptionStatus();

        if (!$merchant->canAccess()) {
            return response()->json([
                'success' => false,
                'error'   => 'subscription_expired',
                'message' => 'Masa trial/langganan Anda telah berakhir. Silakan lakukan pembayaran untuk melanjutkan.',
                'subscription' => $merchant->subscriptionInfo(),
            ], 403);
        }

        return $next($request);
    }
}
