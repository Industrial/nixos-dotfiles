//! vbump: per-input flake.lock updates. For each root input of the flake,
//! independently: relock just that input (C++ `nix flake update <input>` stays
//! the resolver), evaluate and dry-build every nixosConfiguration against the
//! new lock, diff each host's closure against the base (vdiff's `--json`
//! report), and open one pull request per input.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: `common` (errors,
//! commands), `lock` (flake.lock), `nix` (the Nix capability), `differ` (the
//! closure-diff capability), `forge` (the GitHub capability), `body` (the pull
//! request), `run` (the per-input pipeline), `cli` and `app`.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vdiff, plus `match` for a one-variant
// test, which Voltaic's `case` emits where Rust would write `matches!`).
#![allow(
    clippy::match_like_matches_macro,
    clippy::assign_op_pattern,
    clippy::no_effect,
    clippy::unused_unit,
    clippy::collapsible_if,
    clippy::collapsible_else_if,
    clippy::manual_flatten,
    clippy::just_underscores_and_digits,
    clippy::redundant_closure,
    clippy::needless_borrow,
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

voltaic!(common);
voltaic!(lock);
voltaic!(nix);
voltaic!(differ);
voltaic!(forge);
voltaic!(body);
voltaic!(run);
voltaic!(cli);
voltaic!(app);
