//! vwebbrowser: a WebKitGTK browser whose whole program is an id_effect value.
//!
//! The source is Voltaic (`src/*.vlt`); `build.rs` compiles it into `OUT_DIR`
//! and these `include!`s are the library's Voltaic modules. `ui` is the seam
//! (plain-data commands and events, the `Ui` and `UiEvents` capabilities),
//! `app` the root program over it, `error` the typed failures.
//!
//! The seam rule (.maestro/specs/vwebbrowser.md): id_effect owns the program;
//! GTK owns one thread. `gtk_edge` is the only Rust that names a widget, and
//! nothing GTK crosses into the `.vlt` modules.

// Lints on the *shape* of Voltaic's emitted Rust, not on decisions in the
// source (see rust/tools/vmon/src/lib.rs).
#![allow(
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
    clippy::field_reassign_with_default,
    clippy::let_and_return
)]

macro_rules! voltaic {
    ($name:ident) => {
        pub mod $name {
            include!(concat!(env!("OUT_DIR"), "/", stringify!($name), ".rs"));
        }
    };
}

voltaic!(error);
voltaic!(ui);
voltaic!(app);
voltaic!(nav);

pub mod gtk_edge;
