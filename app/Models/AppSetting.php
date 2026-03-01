<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class AppSetting extends Model
{
    protected $fillable = ['key', 'value', 'description'];

    // Cache TTL 10 menit
    private static int $cacheTtl = 600;

    /** Ambil satu nilai setting, dengan fallback default */
    public static function get(string $key, mixed $default = null): mixed
    {
        return Cache::remember("app_setting_{$key}", self::$cacheTtl, function () use ($key, $default) {
            $row = static::where('key', $key)->first();
            return $row ? $row->value : $default;
        });
    }

    /** Set nilai setting, hapus cache */
    public static function set(string $key, mixed $value, ?string $description = null): void
    {
        static::updateOrCreate(
            ['key' => $key],
            array_filter([
                'value'       => (string) $value,
                'description' => $description,
            ], fn($v) => $v !== null),
        );
        Cache::forget("app_setting_{$key}");
    }

    /** Ambil semua settings sebagai array key=>value */
    public static function allAsArray(): array
    {
        return Cache::remember('app_settings_all', self::$cacheTtl, function () {
            return static::all()->pluck('value', 'key')->toArray();
        });
    }

    /** Harga bulanan (integer Rupiah) */
    public static function priceMonthly(): int
    {
        return (int) static::get('price_monthly', 99000);
    }

    /** Harga tahunan (integer Rupiah) */
    public static function priceYearly(): int
    {
        return (int) static::get('price_yearly', 990000);
    }

    /** Durasi trial hari */
    public static function trialDays(): int
    {
        return (int) static::get('trial_days', 7);
    }

    /** Hapus semua cache settings */
    public static function clearCache(): void
    {
        Cache::forget('app_settings_all');
        foreach (static::pluck('key') as $key) {
            Cache::forget("app_setting_{$key}");
        }
    }
}
