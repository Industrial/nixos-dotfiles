//! oomkiller: a daemon that SIGKILLs the current user's largest process once
//! system memory use reaches 90%.
//!
//! The source is Voltaic: `src/policy.vlt` (pure decisions) and
//! `src/daemon.vlt` (sysinfo, /proc, kill, the loop). `build.rs` compiles them
//! into `OUT_DIR`, and these `include!`s are the only Rust in the library.

pub mod policy {
    include!(concat!(env!("OUT_DIR"), "/policy.rs"));
}

// Voltaic 0.2 requires a unit body ending in `case` or `loop` to close with an
// explicit `()` (VLT0113), and emits that `()` as a `();` statement. The
// statement is inert, so clippy's no_effect lint is allowed here and nowhere else.
#[allow(clippy::no_effect)]
pub mod daemon {
    include!(concat!(env!("OUT_DIR"), "/daemon.rs"));
}
