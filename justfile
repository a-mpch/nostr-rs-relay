run-dev:
    RUST_LOG=warn,nostr_rs_relay=debug cargo run --bin nostr-rs-relay

cargo-check *args:
    cargo check --workspace --all-targets {{ args }}

alias cc := cargo-check

cargo-clippy *args:
    cargo clippy --locked --workspace --all-targets {{ args }} -- --deny=warnings

basic-itest:
    ./just/basic-test.sh

cargo-itest:
    ./just/basic-test.sh
    ./just/lexe-auth-test.sh