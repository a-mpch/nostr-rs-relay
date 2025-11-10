# Test Data

This directory contains static keys used for integration testing.

## Files

- `lexe_nsec`: Private key (hex format) for testing /lexe endpoint authentication
- `lexe_pubkey`: Public key (hex format) corresponding to lexe_nsec

## Usage

These keys are referenced in:
- `config.toml`: The `lexe_pubkeys` array includes the pubkey from `lexe_pubkey`
- `just/lexe-auth-test.sh`: The test script reads these files to authenticate

## Security Note

⚠️ **These keys are for testing only.** Never use them in production.
