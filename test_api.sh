#!/bin/bash

# POS API Testing Script
BASE_URL="http://127.0.0.1:8001/api"
TOKEN=""

echo "🚀 Starting POS API Testing..."
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local auth_header=""
    
    if [ ! -z "$TOKEN" ]; then
        auth_header="Authorization: Bearer $TOKEN"
    fi
    
    echo -e "${YELLOW}Testing: $method $endpoint${NC}"
    
    if [ "$method" = "GET" ]; then
        curl -s -X GET "$BASE_URL$endpoint" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "$auth_header"
    else
        curl -s -X $method "$BASE_URL$endpoint" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "$auth_header" \
            -d "$data"
    fi
    echo -e "\n"
}

# Test 1: Login
echo -e "${GREEN}1. Testing Login${NC}"
response=$(api_call "POST" "/auth/login" '{"email":"owner@pos.com","password":"password"}')
echo "$response" | jq '.'

# Extract token from response
TOKEN=$(echo "$response" | jq -r '.data.token // empty')

if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo -e "${GREEN}✅ Login successful! Token received.${NC}\n"
else
    echo -e "${RED}❌ Login failed! Cannot continue testing.${NC}"
    exit 1
fi

# Test 2: Get Profile
echo -e "${GREEN}2. Testing Get Profile${NC}"
api_call "GET" "/auth/profile"

# Test 3: Get Categories
echo -e "${GREEN}3. Testing Get Categories${NC}"
api_call "GET" "/categories"

# Test 4: Create Category
echo -e "${GREEN}4. Testing Create Category${NC}"
api_call "POST" "/categories" '{"name":"Test Category","description":"Category for testing","is_active":true}'

# Test 5: Get Products
echo -e "${GREEN}5. Testing Get Products${NC}"
api_call "GET" "/products"

# Test 6: Get Customers
echo -e "${GREEN}6. Testing Get Customers${NC}"
api_call "GET" "/customers"

# Test 7: Get Branches
echo -e "${GREEN}7. Testing Get Branches${NC}"
api_call "GET" "/branches"

# Test 8: Get Stocks
echo -e "${GREEN}8. Testing Get Stocks${NC}"
api_call "GET" "/stocks?branch_id=1"

# Test 9: Create Sale (POS Transaction)
echo -e "${GREEN}9. Testing Create Sale (POS Transaction)${NC}"
sale_data='{
  "branch_id": 1,
  "customer_id": 1,
  "items": [
    {
      "product_id": 4,
      "quantity": 2,
      "price": 3500,
      "discount": 0
    },
    {
      "product_id": 5,
      "quantity": 1,
      "price": 5000,
      "discount": 0
    }
  ],
  "discount": 0,
  "tax": 0,
  "paid": 15000,
  "payment_method": "cash",
  "notes": "Test sale transaction"
}'
api_call "POST" "/sales" "$sale_data"

# Test 10: Get Sales History
echo -e "${GREEN}10. Testing Get Sales History${NC}"
api_call "GET" "/sales"

# Test 11: Logout
echo -e "${GREEN}11. Testing Logout${NC}"
api_call "POST" "/auth/logout"

echo -e "${GREEN}🎉 API Testing Complete!${NC}"