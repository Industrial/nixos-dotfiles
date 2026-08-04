//! nixq — JSON/attrpath query (pure value algebra + Effect I/O).

pub mod caps;
pub mod commands;
pub mod diff;
pub mod error;
pub mod force_path;
pub mod normalize;
pub mod optics;
pub mod path;

pub use caps::{ClockKey, JsonSourceKey, NixqEnv, live_providers};
pub use diff::{structural_diff, values_equal};
pub use error::{InfraError, PathError, PredicateResult};
pub use force_path::force_paths;
pub use normalize::normalize_value;
pub use optics::{fold_object_keys, value_contains_subset, value_has_attrs};
pub use path::{AttrPath, PathSegment, get_at_path, parse_attrpath};

#[cfg(feature = "optics")]
pub use optics::{object_keys_traversal, value_has_attrs_via_traversal};

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
