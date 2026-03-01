<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('merchants', function (Blueprint $table) {
            $table->enum('subscription_status', ['trial', 'active', 'expired', 'suspended'])
                  ->default('trial')
                  ->after('rejected_at');
            $table->timestamp('trial_ends_at')->nullable()->after('subscription_status');
            $table->timestamp('subscription_ends_at')->nullable()->after('trial_ends_at');
            $table->enum('plan_type', ['monthly', 'yearly'])->nullable()->after('subscription_ends_at');
            $table->timestamp('last_payment_at')->nullable()->after('plan_type');
            $table->decimal('last_payment_amount', 12, 2)->nullable()->after('last_payment_at');
        });

        // Set trial_ends_at = approved_at + 7 hari untuk merchant yang sudah approved
        DB::statement("
            UPDATE merchants
            SET trial_ends_at = DATE_ADD(COALESCE(approved_at, created_at), INTERVAL 7 DAY),
                subscription_status = 'trial'
            WHERE registration_status = 'approved'
              AND trial_ends_at IS NULL
        ");
    }

    public function down(): void
    {
        Schema::table('merchants', function (Blueprint $table) {
            $table->dropColumn([
                'subscription_status',
                'trial_ends_at',
                'subscription_ends_at',
                'plan_type',
                'last_payment_at',
                'last_payment_amount',
            ]);
        });
    }
};
