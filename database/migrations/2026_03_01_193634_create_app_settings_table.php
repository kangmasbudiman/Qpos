<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->string('description')->nullable();
            $table->timestamps();
        });

        // Seed default pricing
        DB::table('app_settings')->insert([
            ['key' => 'price_monthly',      'value' => '99000',  'description' => 'Harga langganan bulanan (Rp)', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'price_yearly',       'value' => '990000', 'description' => 'Harga langganan tahunan (Rp)', 'created_at' => now(), 'updated_at' => now()],
            ['key' => 'trial_days',         'value' => '7',      'description' => 'Durasi trial (hari)',          'created_at' => now(), 'updated_at' => now()],
            ['key' => 'support_email',      'value' => 'support@payzen.id', 'description' => 'Email support',    'created_at' => now(), 'updated_at' => now()],
            ['key' => 'support_whatsapp',   'value' => '',       'description' => 'Nomor WhatsApp support',      'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('app_settings');
    }
};
