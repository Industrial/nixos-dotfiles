//! vhealth: service health probes, not systemd state. Each probe (a TCP
//! connect, an HTTP GET, a unix socket connect, a command, a file's age) runs
//! as an id_effect fiber with its own timeout; a check runs them all at once
//! and returns a structured verdict. Used as a CLI (`vhealth check`), as a
//! daemon exporting node_exporter textfile metrics (`vhealth daemon`), and as
//! a library by vdeploy for its rollback decision (see README.md).
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: the probe model
//! and its pure judgements (`probe`), the configuration (`config`), running
//! the probes (`check`), the reports (`report`), the command line (`cli`) and
//! the program (`app`).

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

pub mod probe {
    include!(concat!(env!("OUT_DIR"), "/probe.rs"));
}

pub mod config {
    include!(concat!(env!("OUT_DIR"), "/config.rs"));
}

pub mod check {
    include!(concat!(env!("OUT_DIR"), "/check.rs"));
}

pub mod report {
    include!(concat!(env!("OUT_DIR"), "/report.rs"));
}

pub mod cli {
    include!(concat!(env!("OUT_DIR"), "/cli.rs"));
}

pub mod app {
    include!(concat!(env!("OUT_DIR"), "/app.rs"));
}
