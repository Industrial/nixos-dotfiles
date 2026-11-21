//! vcache: a Nix binary cache server that reads the local store read-only.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. Pure modules
//! (`nixbase32`, `storepath`, `narinfo`, `signing`) are plain functions; the
//! I/O is id_effect (`nar::stream`, the `store` capability, `http`, `app`).

pub mod nixbase32 {
    include!(concat!(env!("OUT_DIR"), "/nixbase32.rs"));
}

pub mod storepath {
    include!(concat!(env!("OUT_DIR"), "/storepath.rs"));
}

pub mod nar {
    include!(concat!(env!("OUT_DIR"), "/nar.rs"));
}

pub mod narinfo {
    include!(concat!(env!("OUT_DIR"), "/narinfo.rs"));
}

pub mod signing {
    include!(concat!(env!("OUT_DIR"), "/signing.rs"));
}

pub mod db {
    include!(concat!(env!("OUT_DIR"), "/db.rs"));
}

// `errors` declarations emit `_0` bindings in their Display (Voltaic 0.2.1).
#[allow(clippy::just_underscores_and_digits)]
pub mod store {
    include!(concat!(env!("OUT_DIR"), "/store.rs"));
}

pub mod http {
    include!(concat!(env!("OUT_DIR"), "/http.rs"));
}

#[allow(clippy::just_underscores_and_digits)]
pub mod app {
    include!(concat!(env!("OUT_DIR"), "/app.rs"));
}

#[cfg(test)]
mod conformance {
    include!(concat!(env!("OUT_DIR"), "/conformance.rs"));
}
