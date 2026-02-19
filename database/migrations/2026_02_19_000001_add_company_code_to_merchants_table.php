<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use App\Models\Merchant;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('merchants', function (Blueprint $table) {
            $table->string('company_code', 10)->nullable()->unique()->after('name');
        });

        // Generate company_code untuk merchant yang sudah ada
        Merchant::whereNull('company_code')->each(function ($merchant) {
            do {
                $code = strtoupper(Str::random(8));
            } while (Merchant::where('company_code', $code)->exists());

            $merchant->update(['company_code' => $code]);
        });

        // Setelah semua terisi, jadikan not nullable
        Schema::table('merchants', function (Blueprint $table) {
            $table->string('company_code', 10)->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('merchants', function (Blueprint $table) {
            $table->dropColumn('company_code');
        });
    }
};
