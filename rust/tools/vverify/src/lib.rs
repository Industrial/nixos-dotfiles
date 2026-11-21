//! vverify: scheduled, parallel verification of the Nix store against its
//! database (`nix store verify --all`'s content check), reported as JSON and
//! as node_exporter textfile metrics.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. NAR hashing, hash
//! parsing and the store database are nix-store-core's (`../nix-store-core`);
//! what is vverify's own is the per-path verdict (`verify`), the reports
//! (`report`), the command line (`cli`) and the program (`app`).

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vgc): `();` after a unit body and `()`
// arms; one `if let` per `is` test, which Voltaic does not chain; `_0` binders
// in the Display impl of `errors` declarations; nullary lambdas around
// zero-argument functions.
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

pub mod verify {
    include!(concat!(env!("OUT_DIR"), "/verify.rs"));
}

pub mod report {
    include!(concat!(env!("OUT_DIR"), "/report.rs"));
}

pub mod cli {
    include!(concat!(env!("OUT_DIR"), "/cli.rs"));
}

pub mod app {
    include!(concat!(env!("OUT_DIR"), "/app.rs"));
}
