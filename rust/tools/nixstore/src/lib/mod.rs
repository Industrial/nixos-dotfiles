//! nixstore — read-only Nix store path-info from db.sqlite.

pub mod caps;
pub mod commands;
pub mod db;
pub mod error;
pub mod model;

pub use caps::{
    MockPathInfoStore, NixstoreEnv, PathInfoStore, PathInfoStoreKey, SqlitePathInfoStore,
    live_providers, providers_for_store,
};
pub use commands::{PathInfoFlags, cmd_path_info, resolve_store_root};
pub use db::{DEFAULT_STORE_ROOT, db_path_for_store, open_db, open_store_db, query_path_info};
pub use error::InfraError;
pub use model::{PathInfo, QueryOpts, db_hash_to_sri, human_bytes};

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
}
