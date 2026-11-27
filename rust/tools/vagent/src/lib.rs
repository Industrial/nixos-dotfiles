//! vagent: one microVM per agent session (ADR-0009, #353). `vagent run --slot N
//! --branch B` writes the session's inputs into the slot, starts its VM
//! (`microvm-agent-N.service`, through polkit), attaches the terminal with ssh
//! over vsock using a key pair made for this session, and however the session
//! ends: exports the branch when asked (a bundle the guest writes, pushed to
//! `agent/<session>` by the host), copies the transcripts out, stops the VM and
//! deletes the key.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the only Rust in the library: `common` (the
//! error), `plan` (the pure core: names, validation, command lines), `cli`
//! (options), `world` (the capability, live and scripted) and `app`.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (the same set as rust/tools/vswitch).
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
voltaic!(plan);
voltaic!(cli);
voltaic!(world);
voltaic!(app);
