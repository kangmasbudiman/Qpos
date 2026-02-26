<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class SuperAdminSeeder extends Seeder
{
    public function run(): void
    {
        // Cek apakah super_admin sudah ada
        $existing = User::where('role', 'super_admin')->first();

        if ($existing) {
            $this->command->info('Super admin sudah ada: ' . $existing->email);
            return;
        }

        $user = User::create([
            'name'      => 'Super Admin',
            'email'     => 'superadmin@posapp.com',
            'password'  => Hash::make('SuperAdmin@2024'),
            'phone'     => null,
            'role'      => 'super_admin',
            'is_active' => true,
        ]);

        $this->command->info('Super admin berhasil dibuat!');
        $this->command->info('Email   : ' . $user->email);
        $this->command->info('Password: SuperAdmin@2024');
        $this->command->warn('PENTING: Segera ganti password setelah login pertama!');
    }
}
