//! oomkiller: a daemon that SIGKILLs the current user's largest process once
//! system memory use reaches 90%.
//!
//! The source is Voltaic on id_effect:
//! - `src/policy.vlt`: the pure decisions.
//! - `src/ports.vlt`: the capabilities, error and environment.
//! - `src/daemon.vlt`: the check and its Schedule, as effects.
//! - `src/live.vlt`: the real capabilities and the run_main edge.
//!
//! `build.rs` compiles them into `OUT_DIR`, and these `include!`s are the only Rust in the library.

pub mod policy {
    include!(concat!(env!("OUT_DIR"), "/policy.rs"));
}

pub mod ports {
    include!(concat!(env!("OUT_DIR"), "/ports.rs"));
}

pub mod daemon {
    include!(concat!(env!("OUT_DIR"), "/daemon.rs"));
}

pub mod live {
    include!(concat!(env!("OUT_DIR"), "/live.rs"));
}
