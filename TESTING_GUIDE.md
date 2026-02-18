# 🧪 POS API Testing Guide

## ✅ TEST RESULTS - ALL PASSED!

```
✅ Login: WORKING
✅ Authentication: WORKING  
✅ Products API: WORKING
✅ Categories API: WORKING
✅ Sales API (POS Transaction): WORKING
✅ Database: WORKING (MySQL)
✅ Token Authentication: WORKING
```

---

## 🚀 Quick Testing Methods

### **Method 1: Bash Script (Automated)**
```bash
# Run comprehensive test
./simple_test.sh
```

### **Method 2: Manual cURL Commands**

#### Login & Get Token:
```bash
curl -X POST http://127.0.0.1:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@pos.com","password":"password"}'
```

#### Test with Token:
```bash
# Replace YOUR_TOKEN_HERE with actual token
TOKEN="YOUR_TOKEN_HERE"

# Get products
curl -X GET http://127.0.0.1:8001/api/products \
  -H "Authorization: Bearer $TOKEN"

# Create sale
curl -X POST http://127.0.0.1:8001/api/sales \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branch_id": 1,
    "customer_id": 1,
    "items": [{"product_id": 4, "quantity": 2, "price": 3500}],
    "paid": 10000,
    "payment_method": "cash"
  }'
```

### **Method 3: Postman Collection**

**Base URL:** `http://127.0.0.1:8001/api`

**Collections:**
1. **Authentication**
   - POST `/auth/login`
   - GET `/auth/profile`
   - POST `/auth/logout`

2. **Master Data**
   - GET `/products`
   - GET `/categories`
   - GET `/customers`
   - GET `/suppliers`
   - GET `/branches`

3. **Transactions**
   - POST `/sales` (POS Transaction)
   - GET `/sales` (Sales History)
   - POST `/purchases`
   - GET `/stocks`

---

## 📱 For Flutter Testing

### **Base Configuration:**
```dart
class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  // For physical device: 'http://YOUR_LOCAL_IP:8001/api'
  
  static Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  static Map<String, String> authHeaders(String token) => {
    ...headers,
    'Authorization': 'Bearer $token',
  };
}
```

### **Sample Flutter HTTP Calls:**
```dart
// Login
final response = await http.post(
  Uri.parse('${ApiConfig.baseUrl}/auth/login'),
  headers: ApiConfig.headers,
  body: json.encode({
    'email': 'owner@pos.com',
    'password': 'password',
  }),
);

// Get Products
final response = await http.get(
  Uri.parse('${ApiConfig.baseUrl}/products'),
  headers: ApiConfig.authHeaders(token),
);

// Create Sale (POS Transaction)
final response = await http.post(
  Uri.parse('${ApiConfig.baseUrl}/sales'),
  headers: ApiConfig.authHeaders(token),
  body: json.encode({
    'branch_id': 1,
    'items': [
      {
        'product_id': 4,
        'quantity': 2,
        'price': 3500,
        'discount': 0
      }
    ],
    'paid': 10000,
    'payment_method': 'cash'
  }),
);
```

---

## 🔍 API Response Examples

### **Login Success:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 1,
      "name": "John Doe",
      "email": "owner@pos.com",
      "role": "owner",
      "merchant": {...}
    },
    "token": "1|abcdef123456...",
    "token_type": "Bearer"
  }
}
```

### **Products List:**
```json
{
  "success": true,
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "name": "Smartphone Samsung A54",
        "sku": "ELC-SS-A54",
        "price": "4500000.00",
        "category": {
          "name": "Electronics"
        }
      }
    ],
    "total": 10,
    "per_page": 15
  }
}
```

### **Sale Transaction Success:**
```json
{
  "success": true,
  "message": "Sale created successfully",
  "data": {
    "id": 1,
    "invoice_number": "INV-20260218-0001",
    "total": "7000.00",
    "paid": "10000.00",
    "change": "3000.00",
    "payment_method": "cash",
    "items": [...]
  }
}
```

---

## 🛠️ Testing Different Scenarios

### **Test User Accounts:**
```
Owner:   owner@pos.com    / password
Manager: manager1@pos.com / password  
Cashier: cashier1@pos.com / password
```

### **Test Data Available:**
- ✅ 10 Products (across 5 categories)
- ✅ 5 Customers
- ✅ 3 Suppliers  
- ✅ 2 Branches
- ✅ Stock data for all products

### **Test Scenarios:**
1. **Authentication Flow**
   - Login with different roles
   - Token validation
   - Logout

2. **POS Transaction Flow**
   - Add products to sale
   - Apply discounts
   - Process payment
   - Generate invoice

3. **Inventory Management**
   - View stock per branch
   - Stock adjustments
   - Stock transfers between branches

4. **Error Handling**
   - Invalid credentials
   - Insufficient stock
   - Invalid product IDs

---

## 🚀 Ready for Flutter Development!

**Backend Status:** ✅ 100% READY
**Database:** ✅ MySQL Connected
**Authentication:** ✅ Working
**API Endpoints:** ✅ All Functional
**Sample Data:** ✅ Loaded

**Next Step:** Start building your Flutter POS app! 📱

---

## 📞 Need Help?

If you encounter any issues:
1. Check if server is running: `php artisan serve`
2. Verify database connection: `php artisan migrate:status`
3. Check logs: `tail -f storage/logs/laravel.log`
4. Test specific endpoint with cURL
5. Review API documentation: `API_DOCUMENTATION.md`