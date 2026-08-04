//! Discover assay suite files under a directory tree.

use std::path::{Path, PathBuf};

use anyhow::Context;

/// A discovered suite file and its kind.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SuiteFile {
    pub path: PathBuf,
    pub kind: SuiteKind,
}

/// Kind of suite file discovered on disk.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SuiteKind {
    CompatJson,
    CompatNix,
    AssayNix,
}

/// Walk `root` recursively and collect known suite file patterns.
pub fn discover_suites(root: &Path) -> anyhow::Result<Vec<SuiteFile>> {
    let mut suites = Vec::new();
    if root.is_file() {
        if let Some(kind) = suite_kind(root) {
            suites.push(SuiteFile {
                path: root.to_path_buf(),
                kind,
            });
        }
        return Ok(suites);
    }
    walk_dir(root, &mut suites)?;
    suites.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(suites)
}

/// Classify a single path as a suite file, if it matches a known pattern.
pub fn suite_kind(path: &Path) -> Option<SuiteKind> {
    let file_name = path.file_name().and_then(|n| n.to_str())?;

    if file_name == "suite.json" {
        return Some(SuiteKind::CompatJson);
    }
    if file_name.ends_with(".assay.nix") || file_name.ends_with(".assay.json") {
        return Some(SuiteKind::AssayNix);
    }
    if is_fixtures_compat_child(path) {
        if file_name.ends_with(".json") {
            return Some(SuiteKind::CompatJson);
        }
        if file_name.ends_with(".nix") {
            return Some(SuiteKind::CompatNix);
        }
    }
    None
}

fn walk_dir(dir: &Path, suites: &mut Vec<SuiteFile>) -> anyhow::Result<()> {
    for entry in std::fs::read_dir(dir).with_context(|| format!("read dir {}", dir.display()))? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if should_skip_dir(name) {
                continue;
            }
            walk_dir(&path, suites)?;
        } else if let Some(kind) = suite_kind(&path) {
            suites.push(SuiteFile { path, kind });
        }
    }
    Ok(())
}

/// Directories excluded from whole-repo discovery (caches, VCS, build outputs).
fn should_skip_dir(name: &str) -> bool {
    matches!(
        name,
        ".git"
            | ".devenv"
            | ".direnv"
            | ".moon"
            | ".cache"
            | ".hermes"
            | "node_modules"
            | "target"
            | "result"
            | "__pycache__"
            | "vendor"
    ) || name.starts_with("target-")
        || name.starts_with("result-")
}

fn is_fixtures_compat_child(path: &Path) -> bool {
    let compat = path.parent();
    let fixtures = compat.and_then(|p| p.parent());
    compat.is_some_and(|p| p.file_name().is_some_and(|n| n == "compat"))
        && fixtures.is_some_and(|p| p.file_name().is_some_and(|n| n == "fixtures"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn write_file(path: &Path, contents: &str) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, contents).unwrap();
    }

    #[test]
    fn suite_kind_recognizes_patterns() {
        let compat_json = Path::new("fixtures/compat/pass.json");
        let suite_json = Path::new("nested/suite.json");
        let assay = Path::new("lib/foo.assay.nix");
        let compat_nix = Path::new("fixtures/compat/pass.nix");

        assert_eq!(suite_kind(compat_json), Some(SuiteKind::CompatJson));
        assert_eq!(suite_kind(suite_json), Some(SuiteKind::CompatJson));
        assert_eq!(suite_kind(assay), Some(SuiteKind::AssayNix));
        assert_eq!(suite_kind(compat_nix), Some(SuiteKind::CompatNix));
        assert_eq!(suite_kind(Path::new("other/foo.json")), None);
    }

    #[test]
    fn should_skip_dir_ignores_caches_and_vcs() {
        assert!(should_skip_dir(".git"));
        assert!(should_skip_dir("node_modules"));
        assert!(should_skip_dir("target-ci-stable"));
        assert!(should_skip_dir("result-2"));
        assert!(!should_skip_dir("common"));
        assert!(!should_skip_dir("features"));
    }

    #[test]
    fn discover_skips_nested_git_and_node_modules() {
        let root = std::env::temp_dir().join(format!("assay_discover_skip_{}", std::process::id()));
        fs::remove_dir_all(&root).ok();
        write_file(&root.join("keep/demo.assay.nix"), "#");
        write_file(&root.join(".git/hidden.assay.nix"), "#");
        write_file(&root.join("node_modules/pkg/hidden.assay.nix"), "#");
        write_file(&root.join("target/hidden.assay.nix"), "#");

        let found = discover_suites(&root).expect("discover");
        assert_eq!(found.len(), 1);
        assert!(found[0].path.ends_with("keep/demo.assay.nix"));

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn discover_suites_finds_nested_files() {
        let root = std::env::temp_dir().join(format!("assay_discover_{}", std::process::id()));
        fs::remove_dir_all(&root).ok();
        write_file(&root.join("fixtures/compat/one.json"), "{}");
        write_file(&root.join("deep/suite.json"), "{}");
        write_file(&root.join("cases/demo.assay.nix"), "#");

        let found = discover_suites(&root).expect("discover");
        assert_eq!(found.len(), 3);
        assert!(found.iter().any(|s| s.kind == SuiteKind::CompatJson));
        assert!(found.iter().any(|s| s.kind == SuiteKind::AssayNix));

        fs::remove_dir_all(&root).ok();
    }
}
