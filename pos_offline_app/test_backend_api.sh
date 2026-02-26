#!/bin/bash

echo "🧪 ============================================"
echo "   BACKEND REST API TESTING"
echo "   VPS: http://43.133.145.26:8081"
echo "============================================"
echo ""

BASE_URL="http://43.133.145.26:8081/api"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📋 Step 1: Test Backend Health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: GET $BASE_URL"
curl -s -o /dev/null -w "Status Code: %{http_code}\n" $BASE_URL
echo ""

echo "📋 Step 2: Test Login Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: POST $BASE_URL/auth/login"
echo ""
echo "Request Body:"
echo '{
  "email": "admin@pos.com",
  "password": "password123"
}'
echo ""
echo "Response:"

LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "email": "owner@pos.com",
    "password": "password"
  }')

echo "$LOGIN_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$LOGIN_RESPONSE"
echo ""

# Extract token if login successful
TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | grep -o '[^"]*$' | tail -1)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}❌ Login FAILED - No token received${NC}"
  echo ""
  echo "⚠️  TROUBLESHOOTING:"
  echo "   1. Pastikan user sudah dibuat di backend database"
  echo "   2. Command untuk create user (via SSH):"
  echo "      php artisan tinker"
  echo "      \$user = new App\\Models\\User();"
  echo "      \$user->name = 'Admin POS';"
  echo "      \$user->email = 'admin@pos.com';"
  echo "      \$user->password = bcrypt('password123');"
  echo "      \$user->role = 'admin';"
  echo "      \$user->merchant_id = 1;"
  echo "      \$user->branch_id = 1;"
  echo "      \$user->save();"
  echo ""
  exit 1
else
  echo -e "${GREEN}✅ Login SUCCESS - Token received${NC}"
  echo "Token: ${TOKEN:0:50}..."
  echo ""
fi

echo "📋 Step 3: Test Sales Endpoint (without data)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: POST $BASE_URL/sales (with token)"
echo ""

SALES_RESPONSE=$(curl -s -X POST "$BASE_URL/sales" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN")

echo "Response:"
echo "$SALES_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$SALES_RESPONSE"
echo ""

echo "📋 Step 4: Test Sales Endpoint (with complete data)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: POST $BASE_URL/sales (with token + data)"
echo ""

SALES_DATA='{
  "branch_id": 1,
  "invoice_number": "TEST-'$(date +%s)'",
  "subtotal": 50000,
  "discount": 0,
  "tax": 5000,
  "total": 55000,
  "paid": 100000,
  "change": 45000,
  "payment_method": "cash",
  "status": "completed",
  "cashier_name": "Test User",
  "items": [
    {
      "product_id": 1,
      "product_name": "Test Product 1",
      "price": 50000,
      "quantity": 1,
      "discount": 0,
      "subtotal": 50000
    }
  ]
}'

echo "Request Body:"
echo "$SALES_DATA" | python3 -m json.tool 2>/dev/null || echo "$SALES_DATA"
echo ""

FINAL_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BASE_URL/sales" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$SALES_DATA")

HTTP_CODE=$(echo "$FINAL_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
RESPONSE_BODY=$(echo "$FINAL_RESPONSE" | sed '/HTTP_CODE/d')

echo "Response (Status: $HTTP_CODE):"
echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo -e "${GREEN}✅ SUCCESS - Data should be in database!${NC}"
  echo ""
  echo "Next Steps:"
  echo "1. Check backend database:"
  echo "   SELECT * FROM sales ORDER BY id DESC LIMIT 1;"
  echo "2. Check sale_items:"
  echo "   SELECT * FROM sale_items WHERE sale_id = (last_sale_id);"
  echo ""
elif [ "$HTTP_CODE" = "401" ]; then
  echo -e "${RED}❌ FAILED - Unauthenticated (Token issue)${NC}"
  echo "Problem: Token tidak valid atau expired"
  echo ""
elif [ "$HTTP_CODE" = "422" ]; then
  echo -e "${YELLOW}⚠️  FAILED - Validation Error${NC}"
  echo "Problem: Data format tidak sesuai dengan backend validation rules"
  echo "Check response body di atas untuk detail error"
  echo ""
elif [ "$HTTP_CODE" = "500" ]; then
  echo -e "${RED}❌ FAILED - Internal Server Error${NC}"
  echo "Problem: Error di backend (database, kode, dll)"
  echo "Check Laravel logs: tail -f storage/logs/laravel.log"
  echo ""
else
  echo -e "${RED}❌ FAILED - Unexpected response (HTTP $HTTP_CODE)${NC}"
  echo ""
fi

echo "🔍 If Flutter app shows success but no data in DB:"
echo "   → Problem is in BACKEND, not Flutter"
echo "   → Check Laravel validation rules"
echo "   → Check database constraints"
echo "   → Check Laravel logs for errors"
echo ""
