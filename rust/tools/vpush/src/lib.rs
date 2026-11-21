//! vpush: push locally built Nix store paths to the fleet's binary cache host.
//!
//! Two halves. `vpush hook` is Nix's `post-build-hook`: it appends the
//! build's `$OUT_PATHS` to a spool directory and always exits 0, so a cache
//! problem never fails a build. `vpush daemon` drains the spool: for each item
//! it computes the closure from the local store database, opens the cache
//! host's nix-daemon (`ssh <host> nix-daemon --stdio`, or a local socket),
//! skips what the cache already has, and uploads the rest references first,
//! a bounded number at a time, retrying transient failures on an id_effect
//! Schedule.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. The store database,
//! narinfo, signing and the worker protocol are nix-store-core's
//! (`../nix-store-core`); vpush's own are the command line (`cli`), the spool
//! (`spool`), the upload plan (`plan`), the cache link (`remote`), one push
//! (`push`) and the program (`app`).

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vverify).
#![allow(
    clippy::no_effect,
    clippy::unused_unit,
    clippy::collapsible_if,
    clippy::manual_flatten,
    clippy::just_underscores_and_digits,
    clippy::redundant_closure,
    clippy::needless_borrows_for_generic_args,
    clippy::field_reassign_with_default
)]

pub mod cli {
    include!(concat!(env!("OUT_DIR"), "/cli.rs"));
}

pub mod spool {
    include!(concat!(env!("OUT_DIR"), "/spool.rs"));
}

pub mod plan {
    include!(concat!(env!("OUT_DIR"), "/plan.rs"));
}

pub mod remote {
    include!(concat!(env!("OUT_DIR"), "/remote.rs"));
}

pub mod push {
    include!(concat!(env!("OUT_DIR"), "/push.rs"));
}

pub mod app {
    include!(concat!(env!("OUT_DIR"), "/app.rs"));
}
