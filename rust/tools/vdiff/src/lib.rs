//! vdiff: the package-level diff of two Nix closures, as nvd prints it.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. `version` parses
//! store path names and orders versions the way nvd does, `report` is the diff
//! and its two renderings (nvd's text, `--json`), `closure` reads the store
//! database, and `app` is the command line.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (see rust/tools/vgc/src/lib.rs): `_0` binders in the Display impl of
// `errors` declarations, one `if let` per `is` test, nullary lambdas around
// zero-argument functions, borrows Voltaic writes at every call site.
#![allow(
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

voltaic!(version);
voltaic!(report);
voltaic!(closure);
voltaic!(app);

#[cfg(test)]
mod golden {
    include!(concat!(env!("OUT_DIR"), "/golden.rs"));
}
