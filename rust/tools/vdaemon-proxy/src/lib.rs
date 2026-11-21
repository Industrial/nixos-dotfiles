//! vdaemon-proxy: a logging proxy in front of nix-daemon.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the crate. The worker protocol's
//! grammar is nix-store-core's (`nix_store_core::worker`); what is the proxy's
//! own is the `tap` that follows a conversation, the `record` it logs, the
//! `policy` hook, the `upstream` connection made as the client, the `proxy`
//! itself and the `app` edge. `native` answers the read-only ops from the store
//! database, and `conform` (conformance mode, off by default) compares those
//! answers with the daemon's, which clients still get. features/nix/vdaemon-proxy
//! describes the deployment.

// The emitted Rust: `x <- f ...` then `x`, `_0` binders in `errors` Display
// impls, `case`-to-bool tables, and the `()` that ends unit bodies.
#![allow(
    clippy::let_and_return,
    clippy::just_underscores_and_digits,
    clippy::match_like_matches_macro,
    clippy::collapsible_if,
    clippy::needless_borrows_for_generic_args,
    clippy::unused_unit,
    clippy::redundant_closure,
    // `vec!` takes one expression in Voltaic, so buffers are made then resized.
    clippy::slow_vector_initialization,
    clippy::type_complexity,
    clippy::result_large_err,
    // No octal literals in Voltaic: 438 is 0o666.
    clippy::non_octal_unix_permissions
)]

pub mod tap {
    include!(concat!(env!("OUT_DIR"), "/tap.rs"));
}

pub mod record {
    include!(concat!(env!("OUT_DIR"), "/record.rs"));
}

pub mod policy {
    include!(concat!(env!("OUT_DIR"), "/policy.rs"));
}

pub mod native {
    include!(concat!(env!("OUT_DIR"), "/native.rs"));
}

pub mod conform {
    include!(concat!(env!("OUT_DIR"), "/conform.rs"));
}

pub mod upstream {
    include!(concat!(env!("OUT_DIR"), "/upstream.rs"));
}

pub mod proxy {
    include!(concat!(env!("OUT_DIR"), "/proxy.rs"));
}

pub mod app {
    include!(concat!(env!("OUT_DIR"), "/app.rs"));
}
