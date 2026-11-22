//! vlocate: where a command comes from (GH-245). It complements nix-index,
//! which answers from a prebuilt nixpkgs-wide database: vlocate adds the
//! fleet's own systems (this host's, and on the cache host every fleet host's
//! through vci's result roots), read from the store database, and the
//! command-not-found hint for nushell, fish and zsh, falling back to
//! nix-locate for nixpkgs.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: `find` (the pure
//! core: names, hits, the hint), `world` (the capability, live and scripted),
//! `cli` and `app`.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vdeploy).
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

voltaic!(find);
voltaic!(world);
voltaic!(cli);
voltaic!(app);
