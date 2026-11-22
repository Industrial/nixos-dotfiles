//! vci: the fleet's CI on the cache host (GH-242). It lists main and every
//! open same-repository PR, and for each new head commit evaluates and builds
//! every fleet host's toplevel. The cache host's store is what vcache serves,
//! so a built commit is in the cache with nothing pushed: a deploy of it only
//! substitutes. Each result is recorded with its eval and build time
//! (`builds.jsonl`, node_exporter metrics); GitHub commit statuses are an
//! optional, off-by-default path (`--status-token-file`).
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: `common` (the
//! error), `refs` (the pure core: which commit next, which roots go),
//! `report` (the ledger, the metrics, the status text), `caps` (the
//! capabilities, live and scripted), `agent` (one step and the daemon),
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

voltaic!(common);
voltaic!(refs);
voltaic!(report);
voltaic!(caps);
voltaic!(agent);
voltaic!(cli);
voltaic!(app);
