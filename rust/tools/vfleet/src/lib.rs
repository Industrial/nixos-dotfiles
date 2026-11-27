//! vfleet: the fleet inventory (`inventory`) and feature catalog (`catalog`) as
//! Voltaic types (`model`), their cross-host invariants (`check`), the JSON NixOS
//! reads (`emit`) and the command line (`app`). The Voltaic data is the source of
//! truth; common/fleet.json and features/catalog.json are generated from it.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vhealth).
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

macro_rules! voltaic {
    ($name:ident) => {
        pub mod $name {
            include!(concat!(env!("OUT_DIR"), "/", stringify!($name), ".rs"));
        }
    };
}

voltaic!(model);
voltaic!(inventory);
voltaic!(catalog);
voltaic!(check);
voltaic!(emit);
voltaic!(app);
#[cfg(test)]
voltaic!(negative);
