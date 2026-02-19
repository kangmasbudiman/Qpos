<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\User;
use App\Models\Merchant;
use App\Models\Branch;
use App\Models\Category;
use App\Models\Product;
use App\Models\Supplier;
use App\Models\Customer;
use App\Models\Stock;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Create owner user
        $owner = User::create([
            'name' => 'John Doe',
            'email' => 'owner@pos.com',
            'password' => Hash::make('password'),
            'phone' => '081234567890',
            'role' => 'owner',
            'is_active' => true,
        ]);

        // Create merchant
  Merchant::create([
    'name' => 'My POS Business',
    'company_code' => 'POS001',
    'business_type' => 'Retail',
    'address' => 'Jl. Merdeka No. 123, Jakarta',
    'phone' => '021-12345678',
    'email' => 'info@posbusiness.com',
    'owner_user_id' => 1,
    'is_active' => 1,
])

        // Update owner with merchant_id
        $owner->update(['merchant_id' => $merchant->id]);

        // Create branches
        $branch1 = Branch::create([
            'merchant_id' => $merchant->id,
            'name' => 'Branch Jakarta Pusat',
            'code' => 'JKT-PUSAT',
            'address' => 'Jl. Sudirman No. 45, Jakarta Pusat',
            'phone' => '021-11111111',
            'city' => 'Jakarta',
            'is_active' => true,
        ]);

        $branch2 = Branch::create([
            'merchant_id' => $merchant->id,
            'name' => 'Branch Jakarta Selatan',
            'code' => 'JKT-SELATAN',
            'address' => 'Jl. TB Simatupang No. 88, Jakarta Selatan',
            'phone' => '021-22222222',
            'city' => 'Jakarta',
            'is_active' => true,
        ]);

        // Create manager for branch 1
        User::create([
            'name' => 'Manager Branch 1',
            'email' => 'manager1@pos.com',
            'password' => Hash::make('password'),
            'phone' => '081234567891',
            'role' => 'manager',
            'merchant_id' => $merchant->id,
            'branch_id' => $branch1->id,
            'is_active' => true,
        ]);

        // Create cashier for branch 1
        User::create([
            'name' => 'Cashier Branch 1',
            'email' => 'cashier1@pos.com',
            'password' => Hash::make('password'),
            'phone' => '081234567892',
            'role' => 'cashier',
            'merchant_id' => $merchant->id,
            'branch_id' => $branch1->id,
            'is_active' => true,
        ]);

        // Create categories
        $categories = [
            ['name' => 'Electronics', 'description' => 'Electronic devices and accessories'],
            ['name' => 'Food & Beverage', 'description' => 'Food and drink products'],
            ['name' => 'Fashion', 'description' => 'Clothing and accessories'],
            ['name' => 'Home & Living', 'description' => 'Home appliances and furniture'],
            ['name' => 'Health & Beauty', 'description' => 'Health and beauty products'],
        ];

        foreach ($categories as $cat) {
            Category::create([
                'merchant_id' => $merchant->id,
                'name' => $cat['name'],
                'description' => $cat['description'],
                'is_active' => true,
            ]);
        }

        // Create suppliers
        $suppliers = [
            ['name' => 'PT Supplier Elektronik', 'company_name' => 'Supplier Elektronik Indonesia', 'phone' => '021-33333333'],
            ['name' => 'CV Supplier Makanan', 'company_name' => 'Supplier Makanan Sejahtera', 'phone' => '021-44444444'],
            ['name' => 'PT Fashion Supplier', 'company_name' => 'Fashion Supplier Nusantara', 'phone' => '021-55555555'],
        ];

        foreach ($suppliers as $sup) {
            Supplier::create([
                'merchant_id' => $merchant->id,
                'name' => $sup['name'],
                'company_name' => $sup['company_name'],
                'phone' => $sup['phone'],
                'email' => strtolower(str_replace(' ', '', $sup['name'])) . '@supplier.com',
                'address' => 'Jakarta, Indonesia',
                'is_active' => true,
            ]);
        }

        // Create customers
        $customers = [
            ['name' => 'Ahmad Wijaya', 'phone' => '081111111111', 'email' => 'ahmad@customer.com'],
            ['name' => 'Siti Nurhaliza', 'phone' => '081222222222', 'email' => 'siti@customer.com'],
            ['name' => 'Budi Santoso', 'phone' => '081333333333', 'email' => 'budi@customer.com'],
            ['name' => 'Dewi Lestari', 'phone' => '081444444444', 'email' => 'dewi@customer.com'],
            ['name' => 'Eko Prasetyo', 'phone' => '081555555555', 'email' => 'eko@customer.com'],
        ];

        foreach ($customers as $cust) {
            Customer::create([
                'merchant_id' => $merchant->id,
                'name' => $cust['name'],
                'phone' => $cust['phone'],
                'email' => $cust['email'],
                'address' => 'Jakarta, Indonesia',
                'is_active' => true,
            ]);
        }

        // Create products
        $products = [
            ['category_id' => 1, 'name' => 'Smartphone Samsung A54', 'sku' => 'ELC-SS-A54', 'barcode' => '8801234567890', 'price' => 4500000, 'cost' => 4000000],
            ['category_id' => 1, 'name' => 'Laptop Asus VivoBook', 'sku' => 'ELC-AS-VB', 'barcode' => '8801234567891', 'price' => 8500000, 'cost' => 7500000],
            ['category_id' => 1, 'name' => 'Headphone Sony WH-1000XM5', 'sku' => 'ELC-SN-HP', 'barcode' => '8801234567892', 'price' => 3500000, 'cost' => 3000000],
            ['category_id' => 2, 'name' => 'Indomie Goreng', 'sku' => 'FNB-IM-GR', 'barcode' => '8991234567890', 'price' => 3500, 'cost' => 2500],
            ['category_id' => 2, 'name' => 'Coca Cola 330ml', 'sku' => 'FNB-CC-330', 'barcode' => '8991234567891', 'price' => 5000, 'cost' => 3500],
            ['category_id' => 2, 'name' => 'Kopi Kapal Api', 'sku' => 'FNB-KP-API', 'barcode' => '8991234567892', 'price' => 12000, 'cost' => 9000],
            ['category_id' => 3, 'name' => 'Kaos Polos Hitam', 'sku' => 'FSH-KP-HTM', 'barcode' => '8881234567890', 'price' => 75000, 'cost' => 50000],
            ['category_id' => 3, 'name' => 'Jeans Levis 501', 'sku' => 'FSH-JN-501', 'barcode' => '8881234567891', 'price' => 650000, 'cost' => 500000],
            ['category_id' => 4, 'name' => 'Rice Cooker Miyako', 'sku' => 'HOM-RC-MYK', 'barcode' => '8771234567890', 'price' => 350000, 'cost' => 280000],
            ['category_id' => 5, 'name' => 'Wardah Lipstick', 'sku' => 'BEA-WD-LPS', 'barcode' => '8661234567890', 'price' => 45000, 'cost' => 35000],
        ];

        foreach ($products as $prod) {
            $product = Product::create([
                'merchant_id' => $merchant->id,
                'category_id' => $prod['category_id'],
                'name' => $prod['name'],
                'sku' => $prod['sku'],
                'barcode' => $prod['barcode'],
                'description' => 'High quality product',
                'price' => $prod['price'],
                'cost' => $prod['cost'],
                'unit' => 'pcs',
                'min_stock' => 10,
                'is_active' => true,
            ]);

            // Create initial stock for branch 1
            Stock::create([
                'product_id' => $product->id,
                'branch_id' => $branch1->id,
                'quantity' => rand(20, 100),
            ]);

            // Create initial stock for branch 2
            Stock::create([
                'product_id' => $product->id,
                'branch_id' => $branch2->id,
                'quantity' => rand(15, 80),
            ]);
        }

        $this->command->info('Database seeded successfully!');
        $this->command->info('Owner Email: owner@pos.com');
        $this->command->info('Manager Email: manager1@pos.com');
        $this->command->info('Cashier Email: cashier1@pos.com');
        $this->command->info('Password for all users: password');
    }
}
