//! vdeploy: the fleet's pull-based deploy agent, in OBSERVE mode (GH-159).
//! It polls `main`, verifies the commit, evaluates this host's toplevel
//! derivation, realises it (through the `Fetcher`, else the `Builder`), diffs
//! it against the running system with vdiff, and logs the switch it would
//! make. It never switches: there is no code path that does.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: `common` (errors,
//! commands), `watch` (the pure decision core: latest-wins, debounce),
//! `dotfiles` (the user's checkout, fast-forwarded), `caps` (the
//! capabilities and their live implementations), `report` (the plan and the
//! metrics), `agent` (the poller and the worker), `cli` and `app`.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vbump).
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
voltaic!(watch);
voltaic!(dotfiles);
voltaic!(caps);
voltaic!(report);
voltaic!(apply);
voltaic!(takeover);
voltaic!(agent);
voltaic!(cli);
voltaic!(app);
