run-dev:
    RUST_LOG=warn,nostr_rs_relay=debug cargo run --bin nostr-rs-relay

basic-itest:
    ./just/basic-test.sh
