#!/usr/bin/env bash
set -e

RELAY_URL="ws://localhost:8080"
FAILED=0

echo "🧪 Starting basic relay tests..."

# Generate a test key
echo "📝 Generating test key..."
TEST_NSEC=$(nak key generate)
if [ -z "$TEST_NSEC" ]; then
    echo "   ❌ Failed to generate key"
    exit 1
fi

TEST_PUBKEY=$(nak key public <<< "$TEST_NSEC")
if [ -z "$TEST_PUBKEY" ]; then
    echo "   ❌ Failed to derive public key"
    exit 1
fi

echo "   pubkey: $TEST_PUBKEY"

# Give relay time to start if it just started
sleep 1

# Insert a kind 1 test event directly into the database
echo ""
echo "💾 Inserting kind 1 test event into database..."
TIMESTAMP=$(date +%s)
EVENT_HASH=$(printf "test_event_%s" "$TIMESTAMP" | sha256sum | cut -d' ' -f1)
EVENT_JSON='{"id":"'$EVENT_HASH'","pubkey":"'$TEST_PUBKEY'","created_at":'$TIMESTAMP',"kind":1,"tags":[],"content":"test stored message","sig":"dummy"}'

sqlite3 /Users/mpch/repos/nostr/nostr-rs-relay/nostr.db << EOF
INSERT INTO event (event_hash, first_seen, created_at, author, kind, content)
VALUES (
    x'${EVENT_HASH}',
    $TIMESTAMP,
    $TIMESTAMP,
    x'${TEST_PUBKEY}',
    1,
    '$EVENT_JSON'
);
EOF

if [ $? -eq 0 ]; then
    echo "   ✅ Kind 1 event inserted"
else
    echo "   ❌ Failed to insert event"
    FAILED=$((FAILED + 1))
fi

sleep 1

# Generate a second pubkey for tagging
SECOND_PUBKEY=$(nak key public <<< "$(nak key generate)")

# Test 1: Untargeted subscription for kind 1 (should be rejected)
echo ""
echo "🔍 Test 1: Untargeted subscription for kind 1 (should be rejected)..."
UNTARGETED_RESULT=$(timeout 3 nak req -k 1 -l 10 "$RELAY_URL" 2>&1 || true)
if echo "$UNTARGETED_RESULT" | grep -q "test stored message"; then
    echo "   ❌ Untargeted subscription should not return events"
    FAILED=$((FAILED + 1))
else
    echo "   ✅ Untargeted subscription rejected (no events returned)"
fi

# Test 2: Subscription with only author filter for kind 1 (should be rejected)
echo ""
echo "🔍 Test 2: Subscription with only author filter for kind 1 (should be rejected)..."
AUTHOR_ONLY_RESULT=$(timeout 3 nak req -k 1 -a "$TEST_PUBKEY" -l 10 "$RELAY_URL" 2>&1 || true)
if echo "$AUTHOR_ONLY_RESULT" | grep -q "test stored message"; then
    echo "   ❌ Author-only subscription should be rejected"
    FAILED=$((FAILED + 1))
else
    echo "   ✅ Author-only subscription rejected"
fi

# Test 3: Try to publish unsupported kind (should be rejected)
echo ""
echo "🔍 Test 3: Publishing unsupported kind 1 event (should be rejected)..."
UNSUPPORTED_KIND_RESULT=$(timeout 5 nak event --sec "$TEST_NSEC" -k 1 -p "$SECOND_PUBKEY" -c "hello" "$RELAY_URL" 2>&1 || true)
if echo "$UNSUPPORTED_KIND_RESULT" | grep -q "kind is not supported"; then
    echo "   ✅ Unsupported kind rejected with proper error message"
else
    echo "   ❌ Should reject unsupported kind with error message"
    echo "   $UNSUPPORTED_KIND_RESULT"
    FAILED=$((FAILED + 1))
fi

# Test 4: Targeted subscription with p tag receives ephemeral event
echo ""
echo "🔍 Test 4: Targeted subscription with p tag (subscribe + publish ephemeral)..."

# Start subscription in background with --stream flag
SUBSCRIPTION_OUTPUT=$(mktemp)
timeout 8 nak req --stream -k 23194 -p "$SECOND_PUBKEY" "$RELAY_URL" > "$SUBSCRIPTION_OUTPUT" 2>&1 &
SUBSCRIPTION_PID=$!

# Give subscription time to connect
sleep 2

# Publish NWC event while subscription is active
echo "   📤 Publishing event to active subscription..."
PUBLISH_RESULT=$(timeout 5 nak event --sec "$TEST_NSEC" -k 23194 -p "$SECOND_PUBKEY" -c "test nwc request" "$RELAY_URL" 2>&1 || true)

if echo "$PUBLISH_RESULT" | grep -qE "(OK|success)"; then
    echo "   ✅ Event published successfully"
else
    echo "   ⚠️  Publish result unclear: $PUBLISH_RESULT"
fi

# Wait a bit for event to be received
sleep 2

# Kill the subscription
kill $SUBSCRIPTION_PID 2>/dev/null || true
wait $SUBSCRIPTION_PID 2>/dev/null || true

# Check if subscription received the event
if grep -q "test nwc" "$SUBSCRIPTION_OUTPUT"; then
    echo "   ✅ Targeted subscription received ephemeral event"
else
    echo "   ❌ Targeted subscription should have received event"
    echo "   Subscription output:"
    cat "$SUBSCRIPTION_OUTPUT"
    FAILED=$((FAILED + 1))
fi

rm -f "$SUBSCRIPTION_OUTPUT"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ $FAILED test(s) failed"
    exit 1
fi