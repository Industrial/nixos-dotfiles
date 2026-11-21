//! oomkiller: a daemon that SIGKILLs the current user's largest process once
//! system memory use reaches 90%.
//!
//! The source is Voltaic: `src/policy.vlt` (pure decisions) and
//! `src/daemon.vlt` (sysinfo, /proc, kill, the loop). `build.rs` compiles them
//! into `OUT_DIR`, and these `include!`s are the only Rust in the library.

pub mod policy {
    include!(concat!(env!("OUT_DIR"), "/policy.rs"));
}

pub mod daemon {
    include!(concat!(env!("OUT_DIR"), "/daemon.rs"));
}
