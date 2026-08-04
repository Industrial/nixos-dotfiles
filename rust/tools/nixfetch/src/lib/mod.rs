//! nixfetch — fixed-output fetchers + NAR / flat hash verify (id_effect).

#![forbid(unsafe_code)]

pub mod caps;
pub mod commands;
pub mod error;
pub mod hash_parse;
pub mod ingest;
pub mod nar;
pub mod verify;

#[cfg(test)]
mod coverage_tests;

pub use caps::{
    ClockKey, FsPathIo, GitFetch, GitFetchKey, HttpFetch, HttpFetchKey, LiveGitFetch, LiveHttpFetch,
    MockGitFetch, MockHttpFetch, MockPathIo, NixfetchEnv, PathIo, PathIoKey, StdClock,
    live_providers, mock_env_with, mock_providers,
};
pub use commands::{cmd_fetch_git, cmd_fetch_url, cmd_hash, cmd_store_path, cmd_verify};
pub use error::InfraError;
pub use hash_parse::{
    ExpectedHash, format_digest, format_hex, format_nix32, parse_expected_hash, verify_digest,
};
pub use ingest::{hash_flat_bytes, hash_flat_path};
pub use nar::{hash_path_recursive, nar_bytes, nar_serialize};
pub use verify::{digest_report, make_fixed_output_path};

pub use id_effect::Exit;

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

    #[test]
    fn smoke_hash_flat() {
        use id_effect::{FromEnv, build_env, run_test};
        use std::path::PathBuf;

        use super::{NixfetchEnv, cmd_hash, mock_providers};

        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/flat/hello");
        let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
        assert!(matches!(run_test(cmd_hash(path, false), env), Exit::Success(_)));
    }
}
