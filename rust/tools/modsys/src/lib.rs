//! modsys: the typed module system for #417, NixOS as IaC on Voltaic + id_effect.
//!
//! The source is Voltaic (`src/*.vlt`); build.rs compiles it into `OUT_DIR` and these
//! `include!`s are the only Rust in the crate. Promoted and hardened from the S1b spike
//! (docs/research/417/s1b-voltaic-feature-check.md):
//!
//! - `option`: typed slots (`OptionDecl<T>`), definitions at NixOS priorities, and the
//!   merge strategies `Unique`, `Fold` and the fallible `Merge` (`union_unique` is
//!   `attrsOf` for entries one module owns).
//! - `eval`: typed `Key<T>`s over a type-erased registry, modules with declared reads and
//!   writes run in dependency order, cycles reported as paths, option docs.
//! - `lazy`: a memoised fixpoint for options defined in terms of themselves.
//! - `pure`: evaluation as an `Effect<_, _, HNil>`, and `Fetch` as the only IO capability.
//!
//! Purity has a second fence: clippy.toml bans std's IO surface, and CI's
//! `clippy -D warnings` (bin/ci/cargo-standalone) makes that a failure.

// The allows are on the shape of Voltaic's emitted code, not on decisions in the
// source (see rust/tools/vgc/src/lib.rs).
#![allow(
    clippy::just_underscores_and_digits,
    clippy::redundant_closure,
    clippy::type_complexity
)]

pub mod option {
    include!(concat!(env!("OUT_DIR"), "/option.rs"));
}

pub mod eval {
    include!(concat!(env!("OUT_DIR"), "/eval.rs"));
}

pub mod lazy {
    include!(concat!(env!("OUT_DIR"), "/lazy.rs"));
}

pub mod pure {
    include!(concat!(env!("OUT_DIR"), "/pure.rs"));
}

#[cfg(test)]
mod tests {
    include!(concat!(env!("OUT_DIR"), "/tests.rs"));
}
