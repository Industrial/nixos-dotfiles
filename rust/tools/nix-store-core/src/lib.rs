//! nix-store-core: Nix store primitives shared by the Voltaic store tools.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. Everything is a
//! plain function except `nar::stream`, the id_effect face of the NAR cursor,
//! and `worker`, the daemon protocol client (async, with id_effect effects).
//! README.md documents the public API.

pub mod nixbase32 {
    include!(concat!(env!("OUT_DIR"), "/nixbase32.rs"));
}

pub mod hash {
    include!(concat!(env!("OUT_DIR"), "/hash.rs"));
}

pub mod storepath {
    include!(concat!(env!("OUT_DIR"), "/storepath.rs"));
}

pub mod nar {
    include!(concat!(env!("OUT_DIR"), "/nar.rs"));
}

pub mod narinfo {
    include!(concat!(env!("OUT_DIR"), "/narinfo.rs"));
}

pub mod signing {
    include!(concat!(env!("OUT_DIR"), "/signing.rs"));
}

pub mod drv {
    include!(concat!(env!("OUT_DIR"), "/drv.rs"));
}

pub mod db {
    include!(concat!(env!("OUT_DIR"), "/db.rs"));
}

// Store databases with Nix's schema, for tests: this crate's, and with the
// `test-support` feature (taken as a dev-dependency feature) a consumer's.
#[cfg(any(test, feature = "test-support"))]
pub mod testdb {
    include!(concat!(env!("OUT_DIR"), "/testdb.rs"));
}

// Profile generations and Nix's `--delete-older-than` rule: vgc's module,
// lifted for vgen (GH-190). The allows are on the shape of Voltaic's emitted
// loops and `if let`s, not on decisions in the source (see vgc's lib.rs).
#[allow(
    clippy::collapsible_if,
    clippy::collapsible_else_if,
    clippy::manual_flatten,
    clippy::redundant_closure,
    clippy::needless_borrows_for_generic_args,
    clippy::unused_unit,
    clippy::no_effect
)]
pub mod generations {
    include!(concat!(env!("OUT_DIR"), "/generations.rs"));
}

// The worker protocol's emitted Rust: `x <- f ...` then `x` (an awaited
// binding returned), `_0` binders in the `errors` Display, `case`-to-bool
// tables, and the `()` that ends unit bodies.
#[allow(
    clippy::let_and_return,
    clippy::just_underscores_and_digits,
    clippy::match_like_matches_macro,
    clippy::collapsible_if,
    clippy::needless_borrows_for_generic_args,
    clippy::unused_unit,
    clippy::non_octal_unix_permissions
)]
pub mod worker {
    include!(concat!(env!("OUT_DIR"), "/worker.rs"));
}

#[cfg(test)]
mod conformance {
    include!(concat!(env!("OUT_DIR"), "/conformance.rs"));
}

#[cfg(test)]
mod golden {
    include!(concat!(env!("OUT_DIR"), "/golden.rs"));
}

#[cfg(test)]
#[allow(clippy::let_and_return, clippy::needless_borrows_for_generic_args)]
mod worker_live {
    include!(concat!(env!("OUT_DIR"), "/worker_live.rs"));
}

// veval (GH-243): the shared evaluation record, its key, signature and checks.
pub mod veval {
    include!(concat!(env!("OUT_DIR"), "/veval.rs"));
}
