#!/bin/bash
# Walk the shopping cart through the flow the frontend uses:
# 1. browse products
# 2. fill an anonymous cart (identified by the cartId cookie) and update it
# 3. sign in with Cognito and migrate the anonymous cart to the user
# 4. check the cart total the DynamoDB stream maintains
# 5. check out, which empties the user's cart
set -euo pipefail

STACKNAME=${STACKNAME:-aws-serverless-shopping-cart}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-30}
TEST_PASSWORD='Test-Passw0rd!'

api_url() {
  local api_id
  api_id=$(lstk aws cloudformation describe-stack-resource --stack-name "$STACKNAME-$1" \
    --logical-resource-id "$2" --query StackResourceDetail.PhysicalResourceId --output text)
  echo "https://$api_id.execute-api.localhost.localstack.cloud:4566/Prod"
}

PRODUCTS_API=$(api_url product-mock ProductServiceApi)
CART_API=$(api_url shoppingcart-service CartApi)
TABLE=$(lstk aws cloudformation describe-stack-resource --stack-name "$STACKNAME-shoppingcart-service" \
  --logical-resource-id DynamoDBShoppingCartTable --query StackResourceDetail.PhysicalResourceId --output text)
USER_POOL_ID=$(lstk aws ssm get-parameter --name /serverless-shopping-cart-demo/auth/user-pool-id \
  --query Parameter.Value --output text)
CLIENT_ID=$(lstk aws ssm get-parameter --name /serverless-shopping-cart-demo/auth/user-pool-client-id \
  --query Parameter.Value --output text)
echo "Products API: $PRODUCTS_API"
echo "Cart API: $CART_API"

# request <method> <url> [curl args...]: print the body, fail on a non-2xx status
request() {
  local method=$1 url=$2 body status
  shift 2
  body=$(curl -sk -m 60 -X "$method" -w '\n%{http_code}' "$url" "$@")
  status=${body##*$'\n'}
  body=${body%$'\n'*}
  if [ "${status:0:1}" != "2" ]; then
    echo "Test failed: $method $url returned HTTP $status: $body" >&2
    return 1
  fi
  echo "$body"
}

# status_of <method> <url> [curl args...]: print only the HTTP status
status_of() {
  local method=$1 url=$2
  shift 2
  curl -sk -m 60 -o /dev/null -w '%{http_code}' -X "$method" "$url" "$@"
}

# eventually <description> <command...>: retry a command until it succeeds
eventually() {
  local description=$1
  shift
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    "$@" && return 0
    sleep 2
  done
  echo "Test failed: $description"
  exit 1
}

cart_total() {
  lstk aws dynamodb get-item --table-name "$TABLE" \
    --key "{\"pk\": {\"S\": \"product#$PRODUCT_ID\"}, \"sk\": {\"S\": \"totalquantity\"}}" \
    --query Item.quantity.N --output text
}

total_is() {
  local total
  total=$(cart_total)
  [ "$total" = "None" ] && total=0
  [ "$total" = "$1" ]
}

# 1. Products
products=$(request GET "$PRODUCTS_API/product")
count=$(echo "$products" | jq '.products | length')
PRODUCT_ID=$(echo "$products" | jq -r '.products[0].productId')
PRODUCT_NAME=$(echo "$products" | jq -r '.products[0].name')
if [ "$count" -lt 1 ] || [ -z "$PRODUCT_ID" ]; then
  echo "Test failed: product list is empty: $products"
  exit 1
fi
product=$(request GET "$PRODUCTS_API/product/$PRODUCT_ID")
if ! echo "$product" | jq -e --arg n "$PRODUCT_NAME" '.product.name == $n' > /dev/null; then
  echo "Test failed: GET /product/$PRODUCT_ID returned $product"
  exit 1
fi
echo "PASS: listed $count products and fetched '$PRODUCT_NAME'"

BASE_TOTAL=$(cart_total)
[ "$BASE_TOTAL" = "None" ] && BASE_TOTAL=0

# 2. Anonymous cart. The handlers read the lowercase cookie header.
CART_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
COOKIE="cookie: cartId=$CART_ID"

added=$(request POST "$CART_API/cart" -H "$COOKIE" -H 'Content-Type: application/json' \
  -d "{\"productId\": \"$PRODUCT_ID\", \"quantity\": 2}")
if ! echo "$added" | jq -e '.message == "product added to cart"' > /dev/null; then
  echo "Test failed: POST /cart returned $added"
  exit 1
fi
cart=$(request GET "$CART_API/cart" -H "$COOKIE")
if ! echo "$cart" | jq -e --arg id "$PRODUCT_ID" 'any(.products[]; .sk == $id and .quantity == 2)' > /dev/null; then
  echo "Test failed: anonymous cart after adding 2 items: $cart"
  exit 1
fi
echo "PASS: added 2 items to the anonymous cart"

request PUT "$CART_API/cart/$PRODUCT_ID" -H "$COOKIE" -H 'Content-Type: application/json' \
  -d "{\"productId\": \"$PRODUCT_ID\", \"quantity\": 3}" > /dev/null
cart=$(request GET "$CART_API/cart" -H "$COOKIE")
if ! echo "$cart" | jq -e --arg id "$PRODUCT_ID" 'any(.products[]; .sk == $id and .quantity == 3)' > /dev/null; then
  echo "Test failed: anonymous cart after updating the quantity to 3: $cart"
  exit 1
fi
echo "PASS: updated the quantity to 3"

status=$(status_of POST "$CART_API/cart" -H "$COOKIE" -H 'Content-Type: application/json' \
  -d '{"productId": "does-not-exist", "quantity": 1}')
if [ "$status" != "404" ]; then
  echo "Test failed: adding an unknown product returned HTTP $status, expected 404"
  exit 1
fi
echo "PASS: an unknown product is rejected with 404"

# 3. Sign in and migrate the cart
EMAIL="ci-$(date +%s)@example.com"
lstk aws cognito-idp admin-create-user --user-pool-id "$USER_POOL_ID" --username "$EMAIL" \
  --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
  --message-action SUPPRESS > /dev/null
lstk aws cognito-idp admin-set-user-password --user-pool-id "$USER_POOL_ID" --username "$EMAIL" \
  --password "$TEST_PASSWORD" --permanent
ID_TOKEN=$(lstk aws cognito-idp admin-initiate-auth --user-pool-id "$USER_POOL_ID" --client-id "$CLIENT_ID" \
  --auth-flow ADMIN_NO_SRP_AUTH --auth-parameters USERNAME="$EMAIL",PASSWORD="$TEST_PASSWORD" \
  --query AuthenticationResult.IdToken --output text)
USER_SUB=$(lstk aws cognito-idp admin-get-user --user-pool-id "$USER_POOL_ID" --username "$EMAIL" \
  --query "UserAttributes[?Name=='sub'].Value" --output text)
AUTH="Authorization: $ID_TOKEN"
echo "PASS: signed in as $EMAIL"

status=$(status_of POST "$CART_API/cart/migrate" -H "$COOKIE")
if [ "$status" != "401" ]; then
  echo "Test failed: migrating without a token returned HTTP $status, expected 401"
  exit 1
fi
echo "PASS: the Cognito authorizer rejects an unauthenticated migrate"

migrated=$(request POST "$CART_API/cart/migrate" -H "$COOKIE" -H "$AUTH")
if ! echo "$migrated" | jq -e --arg id "$PRODUCT_ID" 'any(.products[]; .sk == $id and .quantity == 3)' > /dev/null; then
  echo "Test failed: migrate returned $migrated"
  exit 1
fi
cart=$(request GET "$CART_API/cart" -H "$COOKIE" -H "$AUTH")
if ! echo "$cart" | jq -e --arg id "$PRODUCT_ID" 'any(.products[]; .sk == $id and .quantity == 3)' > /dev/null; then
  echo "Test failed: the signed-in cart does not hold the migrated item: $cart"
  exit 1
fi
anonymous_cart_empty() {
  request GET "$CART_API/cart" -H "$COOKIE" | jq -e '.products | length == 0' > /dev/null
}
eventually "the anonymous cart was not emptied through the SQS queue" anonymous_cart_empty
echo "PASS: migrated the cart to user $USER_SUB and emptied the anonymous cart"

# 4. The DynamoDB stream keeps the per-product total across carts
expected=$((BASE_TOTAL + 3))
eventually "cart total for $PRODUCT_ID is $(cart_total), expected $expected" total_is "$expected"
total=$(request GET "$CART_API/cart/$PRODUCT_ID/total")
if ! echo "$total" | jq -e --argjson q "$expected" '.quantity == $q' > /dev/null; then
  echo "Test failed: GET /cart/$PRODUCT_ID/total returned $total, expected $expected"
  exit 1
fi
echo "PASS: the cart total for the product is $expected"

# 5. Checkout
checkout=$(request POST "$CART_API/cart/checkout" -H "$COOKIE" -H "$AUTH")
# The response lists the items that were checked out
if ! echo "$checkout" | jq -e --arg id "$PRODUCT_ID" 'any(.products[]; .sk == "product#" + $id and .quantity == 3)' > /dev/null; then
  echo "Test failed: checkout returned $checkout"
  exit 1
fi
cart=$(request GET "$CART_API/cart" -H "$COOKIE" -H "$AUTH")
if ! echo "$cart" | jq -e '.products | length == 0' > /dev/null; then
  echo "Test failed: the cart is not empty after checkout: $cart"
  exit 1
fi
eventually "cart total is $(cart_total) after checkout, expected $BASE_TOTAL" total_is "$BASE_TOTAL"
echo "PASS: checkout emptied the cart"

echo "Test passed: the shopping cart handled browsing, the anonymous cart, sign-in, migration and checkout"
