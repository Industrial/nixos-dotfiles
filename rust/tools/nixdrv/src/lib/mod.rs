//! nixdrv — derivation ATerm/JSON parse, project, CA store-path helpers.

pub mod ca;
pub mod caps;
pub mod commands;
pub mod error;
pub mod hash;
pub mod model;
pub mod parse_aterm;
pub mod parse_json;
pub mod project;
pub mod store_path;

pub use ca::{FileIngestionMethod, fixed_output_path, make_store_path, text_path};
pub use caps::{ClockKey, DrvSource, DrvSourceKey, FsDrvSource, MockDrvSource, NixdrvEnv, live_providers};
pub use commands::{
    cmd_parse, cmd_project, cmd_store_path_make_fixed, cmd_store_path_parse, derivation_to_json,
};
pub use error::{InfraError, ParseError};
pub use hash::{compress_hash, nix_base32_decode, nix_base32_encode, NIX_BASE32_ALPHABET};
pub use model::{Derivation, DerivationOutput};
pub use parse_aterm::parse_drv_aterm;
pub use project::project;
pub use store_path::{DEFAULT_STORE_DIR, StorePath, parse_store_path};

pub use id_effect::Exit;

#[cfg(test)]
mod coverage_tests;

#[cfg(test)]
mod id_effect_dep_smoke {
    use id_effect::Exit;

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
