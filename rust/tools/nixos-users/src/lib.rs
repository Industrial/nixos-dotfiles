//! nixos-users: the repository's NixOS users and groups as Voltaic modules over modsys
//! (#417 S3, #457). The first subtree Voltaic owns: the modules are evaluated at
//! `R = HNil` and rendered to `features/nixos/users/voltaic.json`, which the features
//! import. The source is Voltaic (`src/*.vlt`); build.rs compiles it into `OUT_DIR`.

#![allow(
    // A `case` with a `None -> ()` arm; Voltaic has no `if let`.
    clippy::single_match,
    clippy::just_underscores_and_digits,
    clippy::redundant_closure,
    clippy::type_complexity
)]

/// The committed JSON, compiled in for the drift test. A compile-time read, not IO
/// at evaluation.
pub const COMMITTED: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../../features/nixos/users/voltaic.json"
));

pub mod types {
    include!(concat!(env!("OUT_DIR"), "/types.rs"));
}

pub mod options {
    include!(concat!(env!("OUT_DIR"), "/options.rs"));
}

pub mod fragments {
    include!(concat!(env!("OUT_DIR"), "/fragments.rs"));
}

pub mod json {
    include!(concat!(env!("OUT_DIR"), "/json.rs"));
}

pub mod generate {
    include!(concat!(env!("OUT_DIR"), "/generate.rs"));
}

#[cfg(test)]
mod tests {
    include!(concat!(env!("OUT_DIR"), "/tests.rs"));
}
