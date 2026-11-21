//! vwhy: why one store path depends on another, and what a closure's size is
//! made of. Replaces `nix why-depends` and nix-tree for day-to-day use.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. `graph` holds the
//! questions (shortest chain, every chain, dominators), `store` reads the
//! closure graph from the store database, `render` prints the answers and
//! `app` is the command line.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (see rust/tools/vdiff/src/lib.rs): `_0` binders in the Display impl
// of `errors` declarations, one `if let` per `is` test, nullary lambdas around
// zero-argument functions, borrows Voltaic writes at every call site, and
// `x = x + 1` for every `x := x + 1`.
#![allow(
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

voltaic!(graph);
voltaic!(store);
voltaic!(render);
voltaic!(app);
