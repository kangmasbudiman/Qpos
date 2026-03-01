<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use Illuminate\Http\Request;

class AppSettingController extends Controller
{
    /**
     * GET /settings/public
     * Harga & info publik — bisa diakses semua user (termasuk merchant).
     * Digunakan Flutter untuk menampilkan harga di layar expired/banner.
     */
    public function public(): \Illuminate\Http\JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => [
                'price_monthly'    => AppSetting::priceMonthly(),
                'price_yearly'     => AppSetting::priceYearly(),
                'trial_days'       => AppSetting::trialDays(),
                'support_email'    => AppSetting::get('support_email', 'support@payzen.id'),
                'support_whatsapp' => AppSetting::get('support_whatsapp', ''),
            ],
        ]);
    }

    /**
     * GET /settings  (super admin only)
     * Semua settings lengkap dengan description.
     */
    public function index(): \Illuminate\Http\JsonResponse
    {
        $settings = AppSetting::orderBy('key')->get()
            ->map(fn($s) => [
                'key'         => $s->key,
                'value'       => $s->value,
                'description' => $s->description,
            ]);

        return response()->json(['success' => true, 'data' => $settings]);
    }

    /**
     * PUT /settings  (super admin only)
     * Body: { settings: { price_monthly: 99000, price_yearly: 990000, ... } }
     */
    public function update(Request $request): \Illuminate\Http\JsonResponse
    {
        $request->validate([
            'settings'                  => 'required|array',
            'settings.price_monthly'    => 'sometimes|numeric|min:0',
            'settings.price_yearly'     => 'sometimes|numeric|min:0',
            'settings.trial_days'       => 'sometimes|integer|min:1|max:365',
            'settings.support_email'    => 'sometimes|email',
            'settings.support_whatsapp' => 'sometimes|string|max:20',
        ]);

        foreach ($request->settings as $key => $value) {
            // Hanya izinkan key yang dikenal
            if (in_array($key, ['price_monthly', 'price_yearly', 'trial_days', 'support_email', 'support_whatsapp'])) {
                AppSetting::set($key, $value);
            }
        }

        AppSetting::clearCache();

        return response()->json([
            'success' => true,
            'message' => 'Pengaturan berhasil disimpan',
            'data'    => [
                'price_monthly'    => AppSetting::priceMonthly(),
                'price_yearly'     => AppSetting::priceYearly(),
                'trial_days'       => AppSetting::trialDays(),
                'support_email'    => AppSetting::get('support_email'),
                'support_whatsapp' => AppSetting::get('support_whatsapp'),
            ],
        ]);
    }
}
