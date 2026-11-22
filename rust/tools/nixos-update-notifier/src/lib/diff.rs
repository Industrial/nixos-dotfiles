use std::fmt;

use regex::Regex;
use serde::Deserialize;
use thiserror::Error;

/// A single package-level change between two store closures.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackageChange {
    pub name: String,
    pub detail: String,
}

impl PackageChange {
    pub fn new(name: impl Into<String>, detail: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            detail: detail.into(),
        }
    }
}

impl fmt::Display for PackageChange {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.detail.is_empty() {
            write!(f, "{}", self.name)
        } else {
            write!(f, "{}: {}", self.name, self.detail)
        }
    }
}

#[derive(Debug, Error)]
pub enum DiffError {
    #[error("failed to compile diff-closures parser: {0}")]
    Regex(#[from] regex::Error),
    #[error("vdiff --json output is not valid: {0}")]
    Json(#[from] serde_json::Error),
    #[error("vdiff --json schema {0} is not supported (expected {VDIFF_SCHEMA})")]
    Schema(u64),
}

/// The `vdiff --json` schema this parser reads (rust/tools/vdiff/README.md).
pub const VDIFF_SCHEMA: u64 = 1;

/// One package entry of `vdiff --json`. Unknown fields are ignored.
#[derive(Debug, Deserialize)]
struct VdiffPackage {
    name: String,
    kind: String,
    old: Vec<String>,
    new: Vec<String>,
}

/// The parts of a `vdiff --json` report the notifier uses. `selectionChanged` is left
/// out on purpose: same versions on both sides is not an update.
#[derive(Debug, Deserialize)]
struct VdiffReport {
    schema: u64,
    changed: Vec<VdiffPackage>,
    added: Vec<VdiffPackage>,
    removed: Vec<VdiffPackage>,
}

/// One side's versions as `nix store diff-closures` writes them: comma separated,
/// `ε` for a path with no version, `∅` when the package is not on that side.
fn versions_text(versions: &[String]) -> String {
    if versions.is_empty() {
        return "∅".into();
    }
    versions
        .iter()
        .map(|v| if v.is_empty() { "ε" } else { v.as_str() })
        .collect::<Vec<_>>()
        .join(", ")
}

/// Parse `vdiff --json` (schema 1) into package changes, in the notifier's
/// `name: old → new` form. Version changes come first, then added, then removed
/// packages, each sorted by name as vdiff sorts them. A downgrade says so.
pub fn parse_vdiff_json(json: &str) -> Result<Vec<PackageChange>, DiffError> {
    let report: VdiffReport = serde_json::from_str(json)?;
    if report.schema != VDIFF_SCHEMA {
        return Err(DiffError::Schema(report.schema));
    }
    let changes = report
        .changed
        .iter()
        .chain(&report.added)
        .chain(&report.removed)
        .map(|p| {
            let mut detail = format!("{} → {}", versions_text(&p.old), versions_text(&p.new));
            if p.kind == "downgraded" {
                detail.push_str(" (downgrade)");
            }
            PackageChange::new(p.name.clone(), detail)
        })
        .collect();
    Ok(changes)
}

/// Parse `nix store diff-closures` stdout into package changes. Only the rollback
/// differ (`--differ nix`) uses this; the default is [`parse_vdiff_json`].
///
/// Expected lines look like:
/// - `firefox: 128.0 → 129.0`
/// - `firefox: 128.0 → 129.0, +12.3 MiB`
/// - `bluez-qt: +12.6 KiB`
/// - `kdeconnect: 20.08.2 → ∅, -6597.8 KiB`
pub fn parse_diff_closures(output: &str) -> Result<Vec<PackageChange>, DiffError> {
    let line_re = Regex::new(
        r"(?x)
        ^
        (?P<name>[A-Za-z0-9._+-]+)
        :\s*
        (?P<detail>.*)
        $
        ",
    )?;

    let mut changes = Vec::new();
    for raw in output.lines() {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        // Skip progress / warning noise from experimental nix CLI.
        if line.starts_with("warning:") || line.starts_with("evaluating") {
            continue;
        }
        if let Some(caps) = line_re.captures(line) {
            changes.push(PackageChange::new(
                caps.name("name").unwrap().as_str(),
                caps.name("detail").unwrap().as_str().trim(),
            ));
        }
    }
    Ok(changes)
}

#[cfg(test)]
mod vdiff_tests {
    use super::{DiffError, PackageChange, parse_vdiff_json};
    use crate::format::format_notification_bodies;

    // Captured with `vdiff --json` on drakkar (read-only), two system generations each.
    const SMALL: &str = include_str!("../../tests/fixtures/vdiff-drakkar-494-520.json");
    const NONE: &str = include_str!("../../tests/fixtures/vdiff-drakkar-519-520.json");
    const LARGE: &str = include_str!("../../tests/fixtures/vdiff-drakkar-493-494.json");

    fn lines(changes: &[PackageChange]) -> Vec<String> {
        changes.iter().map(ToString::to_string).collect()
    }

    #[test]
    fn real_pair_lists_changed_then_added_then_removed() {
        let changes = parse_vdiff_json(SMALL).unwrap();
        assert_eq!(
            lines(&changes),
            [
                "voltaic: 0.2.1 → 0.3.0",
                "etc-overlay-carry-out: ∅ → ε",
                "unit-vci.service: ∅ → ε",
                "unit-vexporter.service: ∅ → ε",
                "vci: ∅ → 0.1.0",
                "vexporter: ∅ → 0.1.0",
                "vlocate: ∅ → 0.1.0",
                "vswitch: ∅ → ε, 0.1.0",
                "command-not-found: ε → ∅",
            ]
        );
    }

    #[test]
    fn identical_closures_have_no_changes() {
        assert!(parse_vdiff_json(NONE).unwrap().is_empty());
    }

    #[test]
    fn large_real_pair_counts_every_entry_but_selection_changes() {
        let changes = parse_vdiff_json(LARGE).unwrap();
        // 70 version changes, 84 added, 29 removed; the 1 selection-only change is not an update.
        assert_eq!(changes.len(), 70 + 84 + 29);
        assert!(!changes.iter().any(|c| c.name == "keyutils"));
        let chromium = changes.iter().find(|c| c.name == "chromium").unwrap();
        assert_eq!(
            chromium.detail,
            "157.0.8103.78, 157.0.8103.78_fish-completions, 157.0.8103.78-sandbox → \
158.0.8127.36, 158.0.8127.36_fish-completions, 158.0.8127.36-sandbox"
        );
    }

    #[test]
    fn downgrades_are_marked() {
        let changes = parse_vdiff_json(LARGE).unwrap();
        let downgrades = changes
            .iter()
            .filter(|c| c.detail.ends_with(" (downgrade)"))
            .count();
        assert_eq!(downgrades, 13);
    }

    #[test]
    fn summary_text_is_one_line_per_package() {
        let changes = parse_vdiff_json(SMALL).unwrap();
        let bodies = format_notification_bodies(&changes, 900);
        assert_eq!(
            bodies,
            ["voltaic: 0.2.1 → 0.3.0\n\
etc-overlay-carry-out: ∅ → ε\n\
unit-vci.service: ∅ → ε\n\
unit-vexporter.service: ∅ → ε\n\
vci: ∅ → 0.1.0\n\
vexporter: ∅ → 0.1.0\n\
vlocate: ∅ → 0.1.0\n\
vswitch: ∅ → ε, 0.1.0\n\
command-not-found: ε → ∅"]
        );
    }

    #[test]
    fn large_summary_splits_without_dropping_packages() {
        let changes = parse_vdiff_json(LARGE).unwrap();
        let bodies = format_notification_bodies(&changes, 900);
        assert!(bodies.len() > 1);
        assert!(bodies.iter().all(|b| b.len() <= 900));
        let total: usize = bodies.iter().map(|b| b.lines().count()).sum();
        assert_eq!(total, changes.len());
    }

    #[test]
    fn another_schema_is_refused() {
        let json = SMALL.replace("\"schema\": 1", "\"schema\": 2");
        assert!(matches!(parse_vdiff_json(&json), Err(DiffError::Schema(2))));
    }

    #[test]
    fn text_output_is_refused() {
        assert!(matches!(
            parse_vdiff_json("<<< /run/current-system\n>>> result\n"),
            Err(DiffError::Json(_))
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::{PackageChange, parse_diff_closures};

    #[test]
    fn parse_typical_nixos_output_returns_named_packages() {
        let out = "\
acpi-call: 2020-04-07-5.8.16 → 2020-04-07-5.8.18\n\
baloo-widgets: 20.08.1 → 20.08.2\n\
bluez-qt: +12.6 KiB\n\
dolphin: 20.08.1 → 20.08.2, +13.9 KiB\n\
kdeconnect: 20.08.2 → ∅, -6597.8 KiB\n\
kdeconnect-kde: ∅ → 20.08.2, +6599.7 KiB\n";
        let changes = parse_diff_closures(out).unwrap();
        assert_eq!(changes.len(), 6);
        assert_eq!(changes[0].name, "acpi-call");
        assert_eq!(changes[0].detail, "2020-04-07-5.8.16 → 2020-04-07-5.8.18");
        assert_eq!(changes[2].name, "bluez-qt");
        assert_eq!(changes[2].detail, "+12.6 KiB");
        assert_eq!(changes[4].name, "kdeconnect");
        assert_eq!(changes[5].name, "kdeconnect-kde");
    }

    #[test]
    fn parse_empty_output_returns_empty() {
        assert!(parse_diff_closures("").unwrap().is_empty());
        assert!(parse_diff_closures("\n\n  \n").unwrap().is_empty());
    }

    #[test]
    fn parse_skips_warning_lines() {
        let out = "warning: experimental feature\nfirefox: 1 → 2\n";
        let changes = parse_diff_closures(out).unwrap();
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].name, "firefox");
    }

    #[test]
    fn display_formats_name_and_detail() {
        let c = PackageChange::new("firefox", "128 → 129");
        assert_eq!(c.to_string(), "firefox: 128 → 129");
    }

    #[test]
    fn display_formats_name_only_when_detail_empty() {
        let c = PackageChange::new("firefox", "");
        assert_eq!(c.to_string(), "firefox");
    }
}
