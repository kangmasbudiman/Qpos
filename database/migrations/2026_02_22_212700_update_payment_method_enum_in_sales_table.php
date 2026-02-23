<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // ENUM tidak bisa di-alter langsung dengan Blueprint di semua driver,
        // pakai raw SQL untuk update ENUM values
        \DB::statement("ALTER TABLE sales MODIFY COLUMN payment_method ENUM('cash', 'card', 'transfer', 'ewallet', 'debit', 'credit', 'qris', 'mixed') NOT NULL DEFAULT 'cash'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        \DB::statement("ALTER TABLE sales MODIFY COLUMN payment_method ENUM('cash', 'card', 'transfer', 'ewallet') NOT NULL DEFAULT 'cash'");
    }
};
