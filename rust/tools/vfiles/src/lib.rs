//! vfiles: a declarative file linker for NixOS-declared user files.
//!
//! The NixOS module (lib/vfiles.nix) writes a spec, one entry per file; one
//! activation step runs `vfiles --spec <spec> --state-dir /var/lib/vfiles`,
//! which places every file atomically, records what it placed in a manifest,
//! removes the files it owned that left the spec, and reports files edited by
//! hand (drift) instead of overwriting them.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: the decision table
//! (`plan`), the spec and manifest (`spec`), the filesystem steps (`fsops`),
//! the report (`report`) and the program (`app`).

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vverify).
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

pub mod spec {
    include!(concat!(env!("OUT_DIR"), "/spec.rs"));
}

pub mod plan {
    include!(concat!(env!("OUT_DIR"), "/plan.rs"));
}

pub mod fsops {
    include!(concat!(env!("OUT_DIR"), "/fsops.rs"));
}

pub mod report {
    include!(concat!(env!("OUT_DIR"), "/report.rs"));
}

pub mod app {
    include!(concat!(env!("OUT_DIR"), "/app.rs"));
}
