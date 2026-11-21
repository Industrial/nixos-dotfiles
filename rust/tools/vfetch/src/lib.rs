//! vfetch: concurrent closure substitution from Nix binary caches.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. The store
//! primitives (store paths, narinfo, signatures, hashes, the store database)
//! are nix-store-core's (`../nix-store-core`).

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vgc): `();` after a unit body and `()`
// arms, `_0` binders in the Display impl `errors` derives, one `if let` per
// `is` test, `case` where Rust has `matches!`, nullary lambdas around
// zero-argument functions, `return` as an
// early exit, and the effect types spelled out in signatures. `Decoder`'s
// variants differ in size on purpose: one per NAR in flight, never boxed.
#![allow(
    clippy::no_effect,
    clippy::unused_unit,
    clippy::let_unit_value,
    clippy::let_and_return,
    clippy::needless_return,
    clippy::just_underscores_and_digits,
    clippy::collapsible_if,
    clippy::collapsible_else_if,
    clippy::manual_flatten,
    clippy::match_like_matches_macro,
    clippy::redundant_closure,
    clippy::needless_borrows_for_generic_args,
    clippy::field_reassign_with_default,
    clippy::type_complexity,
    clippy::large_enum_variant
)]

macro_rules! voltaic {
    ($name:ident) => {
        pub mod $name {
            include!(concat!(env!("OUT_DIR"), "/", stringify!($name), ".rs"));
        }
    };
}

voltaic!(config);
voltaic!(fault);
voltaic!(plan);
voltaic!(remote);
voltaic!(target);
voltaic!(stage);
voltaic!(importer);
voltaic!(daemon);
voltaic!(fetch);
voltaic!(serve);
voltaic!(app);

#[cfg(test)]
mod tests {
    include!(concat!(env!("OUT_DIR"), "/tests.rs"));
}
