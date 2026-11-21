//! vgc: the Nix garbage collector, written in Voltaic.
//!
//! Every module is a `src/*.vlt` file that `build.rs` compiles into `OUT_DIR`;
//! these `include!`s are the only Rust in the library.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source: `();` after a unit body and `()` arms (inert); one `if let` per
// `is` test, which Voltaic does not chain; `_0` binders in the Display impl it
// derives for error data; nullary lambdas around zero-argument functions.
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

voltaic!(db);
voltaic!(roots);
voltaic!(profiles);
voltaic!(closure);
voltaic!(effects);
voltaic!(lock);
voltaic!(mounts);
voltaic!(delete);
voltaic!(cli);
