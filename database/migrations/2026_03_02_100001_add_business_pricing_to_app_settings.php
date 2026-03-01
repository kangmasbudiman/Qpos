<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $settings = [
            [
                'key'         => 'price_starter_monthly',
                'value'       => '99000',
                'description' => 'Harga langganan Starter per bulan (Rp)',
            ],
            [
                'key'         => 'price_starter_yearly',
                'value'       => '990000',
                'description' => 'Harga langganan Starter per tahun (Rp)',
            ],
            [
                'key'         => 'price_business_monthly',
                'value'       => '199000',
                'description' => 'Harga langganan Business per bulan (Rp)',
            ],
            [
                'key'         => 'price_business_yearly',
                'value'       => '1990000',
                'description' => 'Harga langganan Business per tahun (Rp)',
            ],
        ];

        foreach ($settings as $s) {
            DB::table('app_settings')->updateOrInsert(
                ['key' => $s['key']],
                array_merge($s, [
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }
    }

    public function down(): void
    {
        DB::table('app_settings')->whereIn('key', [
            'price_starter_monthly',
            'price_starter_yearly',
            'price_business_monthly',
            'price_business_yearly',
        ])->delete();
    }
};
