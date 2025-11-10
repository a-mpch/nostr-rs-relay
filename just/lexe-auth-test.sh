#!/usr/bin/env bash
set -e

RELAY_URL="ws://localhost:8080"
LEXE_RELAY_URL="ws://localhost:8080/lexe"
FAILED=0

echo "🧪 Starting /lexe endpoint authentication tests..."

# Step 0: Load test keys from static files
echo ""
echo "📝 Step 0: Loading test keys from tests_data/..."

if [ ! -f "tests_data/lexe_nsec" ] || [ ! -f "tests_data/lexe_pubkey" ]; then
    echo "   ❌ Test key files not found in tests_data/"
    exit 1
fi

LEXE_NSEC=$(cat tests_data/lexe_nsec)
LEXE_PUBKEY=$(cat tests_data/lexe_pubkey)

echo "   Lexe pubkey: $LEXE_PUBKEY"

# Generate unauthorized key for testing
UNAUTHORIZED_NSEC=$(nak key generate)
UNAUTHORIZED_PUBKEY=$(nak key public <<< "$UNAUTHORIZED_NSEC")
echo "   Unauthorized pubkey: $UNAUTHORIZED_PUBKEY"

# Generate target pubkey for tagged events
TARGET_PUBKEY=$(nak key public <<< "$(nak key generate)")
echo "   Target pubkey: $TARGET_PUBKEY"

echo ""
echo "⚙️  Note: Start relay with: just run-dev"
echo "   (config.toml already has lexe_pubkeys and nip42_auth configured)"
echo ""

# Give relay time to be ready if just started
sleep 1

# Test 1: Try to subscribe without authentication (should be rejected)
echo ""
echo "🔍 Test 1: Subscription without authentication (should be rejected)..."
UNAUTH_SUB_RESULT=$(timeout 3 nak req -k 23194 -p "$TARGET_PUBKEY" "$LEXE_RELAY_URL" 2>&1 || true)
if echo "$UNAUTH_SUB_RESULT" | grep -q "auth-required"; then
    echo "   ✅ Unauthenticated subscription rejected with auth-required"
elif echo "$UNAUTH_SUB_RESULT" | grep -q "CLOSED"; then
    echo "   ✅ Unauthenticated subscription closed (auth required)"
else
    # Check if we got any events (we shouldn't)
    if echo "$UNAUTH_SUB_RESULT" | grep -q "EVENT"; then
        echo "   ❌ Should not receive events without authentication"
        echo "   Output: $UNAUTH_SUB_RESULT"
        FAILED=$((FAILED + 1))
    else
        echo "   ✅ No events received without authentication"
    fi
fi

# Test 2: Try to publish event without authentication (should be rejected)
echo ""
echo "🔍 Test 2: Publishing event without authentication (should be rejected)..."
UNAUTH_PUB_RESULT=$(timeout 5 nak event --sec "$LEXE_NSEC" -k 23194 -p "$TARGET_PUBKEY" -c "unauthorized publish" "$LEXE_RELAY_URL" 2>&1 || true)
if echo "$UNAUTH_PUB_RESULT" | grep -qE "(auth|authentication|restricted)"; then
    echo "   ✅ Unauthenticated publish rejected"
elif echo "$UNAUTH_PUB_RESULT" | grep -q "false"; then
    echo "   ✅ Event rejected (OK message with false)"
else
    if echo "$UNAUTH_PUB_RESULT" | grep -qE "(true|success)"; then
        echo "   ❌ Should not accept events without authentication"
        echo "   Output: $UNAUTH_PUB_RESULT"
        FAILED=$((FAILED + 1))
    else
        echo "   ✅ Event not accepted"
    fi
fi

# Test 3: Try to subscribe with authentication but unauthorized pubkey (should be rejected)
echo ""
echo "🔍 Test 3: Subscription with wrong authenticated pubkey (should be rejected)..."
WRONG_AUTH_SUB_RESULT=$(timeout 5 nak req --auth --sec "$UNAUTHORIZED_NSEC" -k 23194 -p "$TARGET_PUBKEY" "$LEXE_RELAY_URL" 2>&1 || true)
if echo "$WRONG_AUTH_SUB_RESULT" | grep -q "not authorized"; then
    echo "   ✅ Unauthorized pubkey subscription rejected"
elif echo "$WRONG_AUTH_SUB_RESULT" | grep -q "CLOSED"; then
    echo "   ✅ Subscription closed for unauthorized pubkey"
else
    # Check if we got any events (we shouldn't)
    if echo "$WRONG_AUTH_SUB_RESULT" | grep -q "EVENT"; then
        echo "   ❌ Should not receive events with unauthorized pubkey"
        echo "   Output: $WRONG_AUTH_SUB_RESULT"
        FAILED=$((FAILED + 1))
    else
        echo "   ✅ No events received with unauthorized pubkey"
    fi
fi

# Test 4: Try to publish event with wrong authenticated pubkey (should be rejected)
echo ""
echo "🔍 Test 4: Publishing event with wrong authenticated pubkey (should be rejected)..."
WRONG_AUTH_PUB_RESULT=$(timeout 5 nak event --auth --sec "$UNAUTHORIZED_NSEC" -k 23194 -p "$TARGET_PUBKEY" -c "wrong auth publish" "$LEXE_RELAY_URL" 2>&1 || true)
if echo "$WRONG_AUTH_PUB_RESULT" | grep -qE "(not authorized|restricted)"; then
    echo "   ✅ Unauthorized pubkey publish rejected"
elif echo "$WRONG_AUTH_PUB_RESULT" | grep -q "false"; then
    echo "   ✅ Event rejected (OK message with false)"
else
    if echo "$WRONG_AUTH_PUB_RESULT" | grep -qE "(true|success)"; then
        echo "   ❌ Should not accept events from unauthorized pubkey"
        echo "   Output: $WRONG_AUTH_PUB_RESULT"
        FAILED=$((FAILED + 1))
    else
        echo "   ✅ Event not accepted from unauthorized pubkey"
    fi
fi

# Test 5: Subscribe with correct authenticated pubkey and publish/receive event
echo ""
echo "🔍 Test 5: Authenticated subscription + publish with authorized pubkey (should succeed)..."

# Start subscription in background with --stream flag and authentication
SUBSCRIPTION_OUTPUT=$(mktemp)
timeout 10 nak req --stream --auth --sec "$LEXE_NSEC" -k 23194 -p "$TARGET_PUBKEY" "$LEXE_RELAY_URL" > "$SUBSCRIPTION_OUTPUT" 2>&1 &
SUBSCRIPTION_PID=$!

# Give subscription time to connect and authenticate
sleep 3

# Publish event with authenticated lexe pubkey while subscription is active
echo "   📤 Publishing authenticated event..."
PUBLISH_RESULT=$(timeout 5 nak event --auth --sec "$LEXE_NSEC" -k 23194 -p "$TARGET_PUBKEY" -c "authenticated lexe message" "$LEXE_RELAY_URL" 2>&1 || true)

if echo "$PUBLISH_RESULT" | grep -qE "(true|success)"; then
    echo "   ✅ Event published successfully with authentication"
elif echo "$PUBLISH_RESULT" | grep -q "false"; then
    echo "   ❌ Event should be accepted with proper authentication"
    echo "   Publish result: $PUBLISH_RESULT"
    FAILED=$((FAILED + 1))
else
    echo "   ⚠️  Publish result unclear: $PUBLISH_RESULT"
fi

# Wait for event to be received
sleep 2

# Kill the subscription
kill $SUBSCRIPTION_PID 2>/dev/null || true
wait $SUBSCRIPTION_PID 2>/dev/null || true

# Check if subscription received the event
if grep -q "authenticated lexe message" "$SUBSCRIPTION_OUTPUT"; then
    echo "   ✅ Authenticated subscription received event"
else
    echo "   ❌ Authenticated subscription should have received event"
    echo "   Subscription output:"
    cat "$SUBSCRIPTION_OUTPUT"
    FAILED=$((FAILED + 1))
fi

rm -f "$SUBSCRIPTION_OUTPUT"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ All /lexe authentication tests passed!"
    exit 0
else
    echo "❌ $FAILED test(s) failed"
    exit 1
fi
