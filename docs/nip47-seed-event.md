# Development NIP-47 Seed Event

**WARNING: DO NOT USE THIS EVENT IN PRODUCTION!**

This pre-signed event is for development and testing purposes only.

### Event Details

- **Public key**: `79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798`
- **Event ID**: `9856192b4968ba1f597aada2291d2adaf2f785091db91504caed67d4454e022c`
- **Created**: 1700000000 (Nov 14, 2023)
- **Commands**: `get_info`
- **Encryption**: `nip44_v2`

The private key (`0000000000000000000000000000000000000000000000000000000000000001`) is a well-known test key and should **never** be used in production.

## For Production

Generate and sign your own NIP-47 info event:

### Step 1: Generate a new private key

```bash
# Generate a new key (keep this SECURE and OFFLINE)
PRIVATE_KEY=$(nak key generate)
echo "Private key (KEEP SECRET): $PRIVATE_KEY"

# Get the public key
PUBLIC_KEY=$(nak key public <<< "$PRIVATE_KEY")
echo "Public key: $PUBLIC_KEY"
```

### Step 2: Create and sign the NIP-47 info event

```bash
# Create a signed NIP-47 info event
# Customize the content and tags as needed
EVENT_JSON=$(nak event \
  --sec "$PRIVATE_KEY" \
  -k 13194 \
  -c "get_info" \
  -t encryption=nip44_v2 \
  --created-at $(date +%s))

echo "$EVENT_JSON" | jq '.'
```

### Step 3: Extract fields for config.toml

```bash
echo "[seed_data]"
echo "id = \"$(echo "$EVENT_JSON" | jq -r '.id')\""
echo "pubkey = \"$(echo "$EVENT_JSON" | jq -r '.pubkey')\""
echo "created_at = $(echo "$EVENT_JSON" | jq -r '.created_at')"
echo "sig = \"$(echo "$EVENT_JSON" | jq -r '.sig')\""
echo 'commands = ["get_info"]'
echo 'encryption_methods = ["nip44_v2"]'
```

### Step 4: Update config.toml

Copy the output from Step 3 into your `config.toml` file, replacing the `[seed_data]` section.

## Security Note

**The private key should NEVER be stored on the relay server!**  
  
Sign the event offline, then only deploy the pre-signed event fields (id, pubkey, created_at, sig) to the relay configuration. This way, even if the relay is compromised, the wallet's private key remains secure.
