//! nix-store-core: Nix store primitives shared by the Voltaic store tools.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. Everything is a
//! plain function except `nar::stream`, the id_effect face of the NAR cursor.
//! README.md documents the public API.

pub mod nixbase32 {
    include!(concat!(env!("OUT_DIR"), "/nixbase32.rs"));
}

pub mod hash {
    include!(concat!(env!("OUT_DIR"), "/hash.rs"));
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

pub mod drv {
    include!(concat!(env!("OUT_DIR"), "/drv.rs"));
}

pub mod db {
    include!(concat!(env!("OUT_DIR"), "/db.rs"));
}

#[cfg(test)]
mod conformance {
    include!(concat!(env!("OUT_DIR"), "/conformance.rs"));
}

#[cfg(test)]
mod golden {
    include!(concat!(env!("OUT_DIR"), "/golden.rs"));
}
