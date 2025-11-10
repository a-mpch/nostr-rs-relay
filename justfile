run-dev:
    RUST_LOG=warn,nostr_rs_relay=debug cargo run --bin nostr-rs-relay

cargo-clippy *args:
    cargo clippy --locked --workspace --all-targets {{ args }} -- --deny=warnings

basic-itest:
    ./just/basic-test.sh
