//! nix-hash — 1:1 Rust reimplementation of stock `nix-hash` (id_effect).

#![forbid(unsafe_code)]

pub mod algo;
pub mod convert;
pub mod encode;
pub mod error;
pub mod hash_path;
pub mod run;

#[cfg(test)]
mod oracle;
#[cfg(test)]
mod tools_compat;

pub use algo::HashAlgo;
pub use encode::Encoding;
pub use error::HashError;
pub use run::{run_convert, run_hash_paths};

/// Crate identity for smoke tests and `--version` plumbing.
pub const CRATE_NAME: &str = env!("CARGO_PKG_NAME");
pub const CRATE_VERSION: &str = env!("CARGO_PKG_VERSION");

#[cfg(test)]
mod smoke {
    use super::*;
    use id_effect::Exit;

    #[test]
    fn crate_meta() {
        assert_eq!(CRATE_NAME, "nix-hash");
        assert!(!CRATE_VERSION.is_empty());
    }

    #[test]
    fn id_effect_exit_is_linked() {
        let exit: Exit<(), ()> = Exit::succeed(());
        assert!(matches!(exit, Exit::Success(())));
    }

    #[cfg(feature = "cli-exit")]
    #[test]
    fn id_effect_cli_exit_code_linked() {
        use id_effect_cli::exit_code_for_exit;
        use std::process::ExitCode;
        let code = exit_code_for_exit(Exit::<(), ()>::succeed(()));
        assert_eq!(code, ExitCode::SUCCESS);
    }
}
