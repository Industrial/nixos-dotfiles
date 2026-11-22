//! vexporter: the Nix and fleet metrics no other tool owns (GH-248), as a
//! node_exporter textfile. Each tool keeps writing its own file (vci,
//! vdeploy, vhealth, vverify); vexporter adds the store, the system
//! generations and the deploy lag. A source that fails never blanks the
//! file: what was read is written, with `vexporter_source_up{source}`.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: `sources` (each
//! reading, live), `render` (the pure text), `app` (the daemon and the CLI).

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

voltaic!(render);
voltaic!(sources);
voltaic!(app);
