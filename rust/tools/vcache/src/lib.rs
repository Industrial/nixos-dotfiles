//! vcache: a Nix binary cache server that reads the local store read-only.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library. The store
//! primitives (store paths, nix32, NAR, narinfo, signing, the store database)
//! are nix-store-core's (`../nix-store-core`); what is vcache's own is the URL
//! space (`route`), the `store` capability, `http` and `app`.

pub mod route {
    include!(concat!(env!("OUT_DIR"), "/route.rs"));
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
