# POS Multi-Branch API Documentation

## Base URL
```
http://localhost:8000/api
```

## Authentication
This API uses Laravel Sanctum for authentication. Include the Bearer token in the Authorization header for protected endpoints.

```
Authorization: Bearer {your-token-here}
```

---

## Authentication Endpoints

### Register (Create Merchant & Owner)
**POST** `/auth/register`

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "owner@example.com",
  "password": "password123",
  "password_confirmation": "password123",
  "phone": "081234567890",
  "merchant_name": "My Store",
  "business_type": "Retail"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": { ... },
    "token": "1|xxxxxxxxxxxxx",
    "token_type": "Bearer"
  }
}
```

---

### Login
**POST** `/auth/login`

**Request Body:**
```json
{
  "email": "owner@pos.com",
  "password": "password"
}
```

**Response:**
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
      "merchant": { ... },
      "branch": { ... }
    },
    "token": "2|xxxxxxxxxxxxx",
    "token_type": "Bearer"
  }
}
```

---

### Logout
**POST** `/auth/logout`

**Headers:** `Authorization: Bearer {token}`

---

### Get Profile
**GET** `/auth/profile`

**Headers:** `Authorization: Bearer {token}`

---

### Update Profile
**PUT** `/auth/profile`

**Headers:** `Authorization: Bearer {token}`

**Request Body:**
```json
{
  "name": "John Doe Updated",
  "phone": "081234567890"
}
```

---

### Change Password
**POST** `/auth/change-password`

**Headers:** `Authorization: Bearer {token}`

**Request Body:**
```json
{
  "current_password": "password",
  "new_password": "newpassword123",
  "new_password_confirmation": "newpassword123"
}
```

---

## Master Data Endpoints

### Categories

#### List Categories
**GET** `/categories?search=&is_active=1&per_page=15`

**Headers:** `Authorization: Bearer {token}`

#### Create Category
**POST** `/categories`

**Request Body:**
```json
{
  "name": "Electronics",
  "description": "Electronic items",
  "is_active": true
}
```

#### Get Category
**GET** `/categories/{id}`

#### Update Category
**PUT** `/categories/{id}`

#### Delete Category
**DELETE** `/categories/{id}`

---

### Products

#### List Products
**GET** `/products?search=&category_id=&is_active=1&per_page=15`

#### Create Product
**POST** `/products`

**Request Body:**
```json
{
  "name": "Laptop Asus",
  "category_id": 1,
  "sku": "LAP-ASUS-001",
  "barcode": "1234567890123",
  "description": "Gaming laptop",
  "price": 8500000,
  "cost": 7500000,
  "unit": "pcs",
  "min_stock": 5,
  "is_active": true
}
```

#### Get Product
**GET** `/products/{id}`

#### Update Product
**PUT** `/products/{id}`

#### Delete Product
**DELETE** `/products/{id}`

#### Get Product Stock
**GET** `/products/{id}/stock?branch_id=1`

---

### Suppliers

#### List Suppliers
**GET** `/suppliers?search=&is_active=1`

#### Create Supplier
**POST** `/suppliers`

**Request Body:**
```json
{
  "name": "PT Supplier ABC",
  "company_name": "ABC Company",
  "phone": "021-12345678",
  "email": "supplier@abc.com",
  "address": "Jakarta, Indonesia",
  "is_active": true
}
```

#### Get/Update/Delete Supplier
**GET/PUT/DELETE** `/suppliers/{id}`

---

### Customers

#### List Customers
**GET** `/customers?search=&is_active=1`

#### Create Customer
**POST** `/customers`

**Request Body:**
```json
{
  "name": "Ahmad Wijaya",
  "phone": "081234567890",
  "email": "ahmad@customer.com",
  "address": "Jakarta",
  "birthday": "1990-01-15",
  "is_active": true
}
```

#### Get/Update/Delete Customer
**GET/PUT/DELETE** `/customers/{id}`

---

### Branches

#### List Branches
**GET** `/branches?search=&is_active=1`

#### Create Branch
**POST** `/branches`

**Request Body:**
```json
{
  "name": "Branch Jakarta",
  "code": "JKT-001",
  "address": "Jl. Sudirman No. 1",
  "phone": "021-11111111",
  "city": "Jakarta",
  "is_active": true
}
```

#### Get/Update/Delete Branch
**GET/PUT/DELETE** `/branches/{id}`

---

## Transaction Endpoints

### Sales

#### List Sales
**GET** `/sales?branch_id=&status=&customer_id=&date_from=&date_to=&per_page=15`

#### Create Sale (POS Transaction)
**POST** `/sales`

**Request Body:**
```json
{
  "branch_id": 1,
  "customer_id": 1,
  "items": [
    {
      "product_id": 1,
      "quantity": 2,
      "price": 4500000,
      "discount": 0
    },
    {
      "product_id": 4,
      "quantity": 5,
      "price": 3500,
      "discount": 0
    }
  ],
  "discount": 0,
  "tax": 0,
  "paid": 9020000,
  "payment_method": "cash",
  "notes": "Cash payment"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Sale created successfully",
  "data": {
    "id": 1,
    "invoice_number": "INV-20260218-0001",
    "subtotal": 9017500,
    "total": 9017500,
    "paid": 9020000,
    "change": 2500,
    "items": [ ... ]
  }
}
```

#### Get Sale
**GET** `/sales/{id}`

#### Cancel Sale
**POST** `/sales/{id}/cancel`

---

### Purchases

#### List Purchases
**GET** `/purchases?branch_id=&status=&supplier_id=&date_from=&date_to=`

#### Create Purchase
**POST** `/purchases`

**Request Body:**
```json
{
  "branch_id": 1,
  "supplier_id": 1,
  "purchase_date": "2026-02-18",
  "items": [
    {
      "product_id": 1,
      "quantity": 10,
      "cost": 4000000,
      "discount": 0
    }
  ],
  "discount": 0,
  "tax": 0,
  "notes": "Monthly stock"
}
```

#### Get Purchase
**GET** `/purchases/{id}`

#### Cancel Purchase
**POST** `/purchases/{id}/cancel`

---

## Stock Management Endpoints

### Stock List
**GET** `/stocks?branch_id=1&search=&low_stock=1`

Get all stock for a specific branch. Use `low_stock=1` to filter products below minimum stock.

---

### Stock Adjustment
**POST** `/stocks/adjustment`

Manually adjust stock quantity.

**Request Body:**
```json
{
  "branch_id": 1,
  "product_id": 1,
  "quantity": 50,
  "notes": "Physical stock count adjustment"
}
```

---

### Stock Transfer Between Branches
**POST** `/stocks/transfer`

**Request Body:**
```json
{
  "from_branch_id": 1,
  "to_branch_id": 2,
  "product_id": 1,
  "quantity": 10,
  "notes": "Transfer to branch 2"
}
```

---

### Stock Movement History
**GET** `/stocks/movements?branch_id=&product_id=&type=&date_from=&date_to=`

Get history of all stock movements. Types: `in`, `out`, `transfer`, `adjustment`

---

## Test Credentials

After running `php artisan migrate:fresh --seed`, use these credentials:

**Owner:**
- Email: `owner@pos.com`
- Password: `password`

**Manager:**
- Email: `manager1@pos.com`
- Password: `password`

**Cashier:**
- Email: `cashier1@pos.com`
- Password: `password`

---

## Error Response Format

All error responses follow this format:

```json
{
  "success": false,
  "message": "Error message here",
  "errors": {
    "field_name": ["Error detail"]
  }
}
```

---

## Notes for Flutter Development

1. **Base URL**: Update this to your local IP when testing on physical device (e.g., `http://192.168.1.10:8000/api`)

2. **Token Storage**: Store the auth token securely using `flutter_secure_storage`

3. **Headers**: Always include `Accept: application/json` and `Content-Type: application/json`

4. **Pagination**: Most list endpoints return paginated results with meta data

5. **Date Format**: Use ISO 8601 format (YYYY-MM-DD) for dates

6. **Decimal Numbers**: Price, cost, and monetary values use 2 decimal places

7. **Stock Management**: Always check stock availability before creating sales

8. **Multi-tenant**: All data is automatically scoped to the logged-in user's merchant

---

## Development Commands

```bash
# Start development server
php artisan serve

# Run migrations
php artisan migrate

# Fresh migration with seed data
php artisan migrate:fresh --seed

# Clear cache
php artisan cache:clear
php artisan config:clear
php artisan route:clear

# List all routes
php artisan route:list --path=api
```
