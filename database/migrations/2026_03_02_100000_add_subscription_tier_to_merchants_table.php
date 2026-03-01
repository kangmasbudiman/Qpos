<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('merchants', function (Blueprint $table) {
            $table->enum('subscription_tier', ['starter', 'business'])
                  ->default('starter')
                  ->after('plan_type')
                  ->comment('Tier langganan: starter atau business');
        });
    }

    public function down(): void
    {
        Schema::table('merchants', function (Blueprint $table) {
            $table->dropColumn('subscription_tier');
        });
    }
};
