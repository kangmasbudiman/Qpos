# 🔧 Backend Setup Guide - POS Offline App

## 📊 Current Status

✅ **Backend Running:** http://43.133.145.26:8081  
✅ **Flutter App:** Configured & Ready  
❌ **Problem:** User belum ada di database  
❌ **Result:** Login gagal → No token → Sync gagal  

---

## 🎯 Quick Fix - Create User

### Option 1: Via SSH + Tinker (Recommended)

```bash
# 1. SSH ke VPS
ssh user@43.133.145.26

# 2. Masuk ke directory Laravel project
cd /path/to/laravel/project

# 3. Jalankan tinker
php artisan tinker

# 4. Create user (paste satu per satu)
$user = new App\Models\User();
$user->name = 'Admin POS';
$user->email = 'admin@pos.com';
$user->password = bcrypt('password123');
$user->role = 'admin';
$user->merchant_id = 1;
$user->branch_id = 1;
$user->save();

# 5. Verify
App\Models\User::where('email', 'admin@pos.com')->first();

# 6. Exit tinker
exit
```

### Option 2: Via Database Direct (phpMyAdmin/MySQL)

```sql
INSERT INTO users (name, email, password, role, merchant_id, branch_id, created_at, updated_at)
VALUES (
  'Admin POS',
  'admin@pos.com',
  '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: password
  'admin',
  1,
  1,
  NOW(),
  NOW()
);
```

**Note:** Password hash di atas adalah untuk "password". Untuk "password123", generate dengan:
```php
php artisan tinker
bcrypt('password123')
```

### Option 3: Via Seeder

```bash
# Create seeder
php artisan make:seeder UserSeeder

# Edit database/seeders/UserSeeder.php
# Lalu run:
php artisan db:seed --class=UserSeeder
```

---

## 🧪 Test After Creating User

### Quick Test - Login

```bash
curl -X POST http://43.133.145.26:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@pos.com","password":"password123"}'
```

**Expected Response:**
```json
{
  "success": true,
  "token": "1|xxxxxxxxxxxxxxxxxxxxx",
  "user": {
    "id": 1,
    "name": "Admin POS",
    "email": "admin@pos.com",
    ...
  }
}
```

### Full Test - Use Script

```bash
# Run testing script
./test_backend_api.sh
```

**Expected:**
- ✅ Login SUCCESS
- ✅ Token received
- ✅ Sales endpoint test
- ✅ Data inserted to database

---

## 📱 Test from Flutter App

After user is created in backend:

1. **Open POS App**
2. **Login Screen:**
   - Email: `admin@pos.com`
   - Password: `password123`
3. **Should login successfully**
4. **Make a transaction:**
   - Add products to cart
   - Checkout
   - Complete payment
5. **Check Sync:**
   - Dashboard → "Sync Debug"
   - Should show: "Has Token: YES ✅"
   - Click "Test Manual Sync"
   - Check backend database

---

## 🔍 Troubleshooting

### Login still fails after creating user?

**Check 1: User exists?**
```sql
SELECT * FROM users WHERE email = 'admin@pos.com';
```

**Check 2: Password correct?**
```php
// In tinker
$user = App\Models\User::where('email', 'admin@pos.com')->first();
Hash::check('password123', $user->password); // Should return true
```

**Check 3: Laravel logs**
```bash
tail -f storage/logs/laravel.log
```

### Sync still fails after login?

**Check 1: Token saved?**
- Open app → Sync Debug → Check "Has Token"

**Check 2: Backend receives request?**
```bash
# In Laravel project
tail -f storage/logs/laravel.log
```

**Check 3: Database constraints**
```sql
-- Check if sales table exists
SHOW TABLES LIKE 'sales';

-- Check table structure
DESCRIBE sales;

-- Check foreign key constraints
SHOW CREATE TABLE sale_items;
```

### Data not in database after sync success?

**Possible causes:**

1. **Validation Error (Silent Fail)**
   - Check Laravel validation rules
   - Check required fields match

2. **Database Transaction Rollback**
   - Check for database errors in logs
   - Check foreign key constraints

3. **Observer/Event Preventing Save**
   - Check Laravel Model events
   - Check observers

**Debug:**
```php
// In Laravel Controller
Log::info('Sales data received:', $request->all());
```

---

## 📋 Checklist

**Backend Setup:**
- [ ] Laravel project deployed on VPS
- [ ] Database created & migrated
- [ ] User created in database
- [ ] API routes accessible
- [ ] CORS enabled for mobile app

**Flutter App:**
- [ ] Backend URL configured (`http://43.133.145.26:8081/api`)
- [ ] Can login successfully
- [ ] Token saved in secure storage
- [ ] Sync queue working
- [ ] Sync service configured

**Testing:**
- [ ] Login via app works
- [ ] Login via curl works
- [ ] POS transaction creates sale
- [ ] Sale added to sync queue
- [ ] Manual sync works
- [ ] Data appears in backend database

---

## 🆘 Need Help?

1. **Run test script:** `./test_backend_api.sh`
2. **Check Sync Debug** in app
3. **Share screenshots/logs** for analysis

---

Last Updated: 2026-02-18
