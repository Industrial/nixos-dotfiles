//! vbuild: a load-aware Nix build hook, in place of `nix __build-remote`.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. The `.drv` parser
//! is nix-store-core's (`../nix-store-core`).

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (vgc's list, plus: `:=` reassignment emits `x = x + n`; `mut v =
// Vec::new ()` + `resize` is the only zero-fill spelling; interpolated
// strings emit `format!` even with nothing to interpolate; `case` emits
// `match` where `matches!` would do; tests compare bools with `assert_eq!`).
#![allow(
    clippy::assign_op_pattern,
    clippy::slow_vector_initialization,
    clippy::useless_format,
    clippy::match_like_matches_macro,
    clippy::bool_assert_comparison,
    clippy::no_effect,
    clippy::unused_unit,
    clippy::collapsible_if,
    clippy::collapsible_else_if,
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

voltaic!(wire);
voltaic!(machines);
voltaic!(run);
voltaic!(select);
voltaic!(probe);
voltaic!(slots);
voltaic!(copier);
voltaic!(worker_copy);
voltaic!(hook);
voltaic!(app);
