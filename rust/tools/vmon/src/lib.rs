//! vmon: a monitor for Nix's `--log-format internal-json` stream, in place of
//! nix-output-monitor (`nom --json`).
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. `event` decodes a
//! line into nix-store-core's stderr message family, `monitor` folds the
//! messages into the state of the run, `render` draws it (the live tree, the
//! plain lines, the summary, the metrics textfile) and `app` is the command
//! line: the I/O and the render tick, as id_effect effects.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (see rust/tools/vdiff/src/lib.rs).
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

voltaic!(event);
voltaic!(monitor);
voltaic!(render);
voltaic!(app);

#[cfg(test)]
mod golden {
    include!(concat!(env!("OUT_DIR"), "/golden.rs"));
}
