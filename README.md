# [nostr-rs-relay](https://git.sr.ht/~gheartsfield/nostr-rs-relay)

This is a [nostr](https://github.com/nostr-protocol/nostr) relay,
written in Rust.  It currently supports the entire relay protocol, and
persists data with SQLite.

The project master repository is available on
[sourcehut](https://sr.ht/~gheartsfield/nostr-rs-relay/), and is
mirrored on [GitHub](https://github.com/scsibug/nostr-rs-relay).

## Fork Modifications

This fork includes the following modifications:

- **Removed PostgreSQL support**: Simplified dependencies by removing experimental PostgreSQL support and maintaining only SQLite
- **Upgraded to Rust 1.90**: Updated Rust toolchain and dependencies
- **Database seeding on startup**: Relay runs stateless with data seeded from config on each startup; all other messages are ephemeral
- **NIP-42 authentication for `/lexe` endpoint**: Added authentication support for the custom Lexe endpoint
- **Enhanced scraper filtering**: Improved bot/scraper detection, including filtering connections without P or E tags
- **CI workflow integration**: Bridged CI workflows from the Lexe repository
- **Code cleanup**: Removed unused code and fixed Clippy warnings

[![builds.sr.ht status](https://builds.sr.ht/~gheartsfield/nostr-rs-relay/commits/master.svg)](https://builds.sr.ht/~gheartsfield/nostr-rs-relay/commits/master?)

![Github CI](https://github.com/scsibug/nostr-rs-relay/actions/workflows/ci.yml/badge.svg)


## Features

[NIPs](https://github.com/nostr-protocol/nips) with a relay-specific implementation are listed here.

- [x] NIP-01: [Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
  * Core event model
  * Hide old metadata events
  * Id/Author prefix search
- [x] NIP-02: [Contact List and Petnames](https://github.com/nostr-protocol/nips/blob/master/02.md)
- [ ] NIP-03: [OpenTimestamps Attestations for Events](https://github.com/nostr-protocol/nips/blob/master/03.md)
- [x] NIP-05: [Mapping Nostr keys to DNS-based internet identifiers](https://github.com/nostr-protocol/nips/blob/master/05.md)
- [x] NIP-09: [Event Deletion](https://github.com/nostr-protocol/nips/blob/master/09.md)
- [x] NIP-11: [Relay Information Document](https://github.com/nostr-protocol/nips/blob/master/11.md)
- [x] NIP-12: [Generic Tag Queries](https://github.com/nostr-protocol/nips/blob/master/12.md)
- [x] NIP-15: [End of Stored Events Notice](https://github.com/nostr-protocol/nips/blob/master/15.md)
- [x] NIP-16: [Event Treatment](https://github.com/nostr-protocol/nips/blob/master/16.md)
- [x] NIP-20: [Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
- [x] NIP-22: [Event `created_at` limits](https://github.com/nostr-protocol/nips/blob/master/22.md) (_future-dated events only_)
- [ ] NIP-26: [Event Delegation](https://github.com/nostr-protocol/nips/blob/master/26.md) (_implemented, but currently disabled_)
- [x] NIP-28: [Public Chat](https://github.com/nostr-protocol/nips/blob/master/28.md)
- [x] NIP-33: [Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
- [x] NIP-40: [Expiration Timestamp](https://github.com/nostr-protocol/nips/blob/master/40.md)
- [x] NIP-42: [Authentication of clients to relays](https://github.com/nostr-protocol/nips/blob/master/42.md)

## Quick Start

### Local Development

Run the relay locally with default settings:

```console
just run-dev
```

### Production Deployment

For production use with the `/lexe` endpoint, specify authorized pubkeys:

```console
$ ./target/release/nostr-rs-relay --lexe-pubkeys <pubkey1>,<pubkey2>,<pubkey3>
```

The `--lexe-pubkeys` flag accepts a comma-separated list of pubkeys that are authorized to use the NIP-42 authenticated `/lexe` endpoint.

## Build and Run (without Docker)

Building `nostr-rs-relay` requires an installation of Cargo & Rust: https://www.rust-lang.org/tools/install

The following OS packages will be helpful; on Debian/Ubuntu:
```console
$ sudo apt-get install build-essential cmake protobuf-compiler pkg-config libssl-dev
```

On OpenBSD:
```console
$ doas pkg_add rust protobuf
```

Clone this repository, and then build a release version of the relay:

```console
$ git clone -q https://git.sr.ht/\~gheartsfield/nostr-rs-relay
$ cd nostr-rs-relay
$ cargo build -q -r
```

The relay executable is now located in
`target/release/nostr-rs-relay`.  In order to run it with logging
enabled, execute it with the `RUST_LOG` variable set:

```console
$ RUST_LOG=warn,nostr_rs_relay=info ./target/release/nostr-rs-relay
Dec 26 10:31:56.455  INFO nostr_rs_relay: Starting up from main
Dec 26 10:31:56.464  INFO nostr_rs_relay::server: listening on: 0.0.0.0:8080
Dec 26 10:31:56.466  INFO nostr_rs_relay::server: db writer created
Dec 26 10:31:56.466  INFO nostr_rs_relay::db: Built a connection pool "event writer" (min=1, max=2)
Dec 26 10:31:56.466  INFO nostr_rs_relay::db: opened database "./nostr.db" for writing
Dec 26 10:31:56.466  INFO nostr_rs_relay::schema: DB version = 11
Dec 26 10:31:56.467  INFO nostr_rs_relay::db: Built a connection pool "maintenance writer" (min=1, max=2)
Dec 26 10:31:56.467  INFO nostr_rs_relay::server: control message listener started
Dec 26 10:31:56.468  INFO nostr_rs_relay::db: Built a connection pool "client query" (min=4, max=8)
```

You now have a running relay, on port `8080`.  Use a `nostr` client or
`websocat` to connect and send/query for events.

## Configuration

The sample [`config.toml`](config.toml) file demonstrates the
configuration available to the relay.  This file is optional, but may
be mounted into a docker container like so:

```console
$ docker run -it -p 7000:8080 \
  --mount src=$(pwd)/config.toml,target=/usr/src/app/config.toml,type=bind \
  --mount src=$(pwd)/data,target=/usr/src/app/db,type=bind \
  --mount src=$(pwd)/index.html,target=/usr/src/app/index.html,type=bind \
  nostr-rs-relay
```

Options include rate-limiting, event size limits, and network address
settings.

## Reverse Proxy Configuration

For examples of putting the relay behind a reverse proxy (for TLS
termination, load balancing, and other features), see [Reverse
Proxy](docs/reverse-proxy.md).

## Dev Channel

For development discussions, please feel free to use the [sourcehut
mailing list](https://lists.sr.ht/~gheartsfield/nostr-rs-relay-devel).

License
---
This project is MIT licensed.

External Documentation and Links
---

* [BlockChainCaffe's Nostr Relay Setup Guide](https://github.com/BlockChainCaffe/Nostr-Relay-Setup-Guide)
