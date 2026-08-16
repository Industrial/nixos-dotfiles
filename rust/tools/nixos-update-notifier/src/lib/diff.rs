use std::fmt;

use regex::Regex;
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
}

/// Parse `nix store diff-closures` stdout into package changes.
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
