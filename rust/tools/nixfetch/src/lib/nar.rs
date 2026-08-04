//! Nix Archive (NAR) serializer + recursive path hashing.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

use crate::error::InfraError;

fn write_padded(out: &mut Vec<u8>, data: &[u8]) {
    let len = data.len() as u64;
    out.extend_from_slice(&len.to_le_bytes());
    out.extend_from_slice(data);
    let pad = (8 - (data.len() % 8)) % 8;
    out.extend(std::iter::repeat_n(0u8, pad));
}

fn write_str(out: &mut Vec<u8>, s: &str) {
    write_padded(out, s.as_bytes());
}

fn serialize_path(path: &Path, out: &mut Vec<u8>) -> Result<(), InfraError> {
    let meta = fs::symlink_metadata(path).map_err(|e| InfraError::Io {
        path: path.display().to_string(),
        message: e.to_string(),
    })?;
    let ft = meta.file_type();

    write_str(out, "(");
    write_str(out, "type");

    if ft.is_symlink() {
        write_str(out, "symlink");
        write_str(out, "target");
        let target = fs::read_link(path).unwrap_or_else(|_| PathBuf::from(""));
        write_str(out, &target.to_string_lossy());
    } else if ft.is_dir() {
        write_str(out, "directory");
        let mut entries: Vec<PathBuf> = fs::read_dir(path)
            .map_err(|e| InfraError::Io {
                path: path.display().to_string(),
                message: e.to_string(),
            })?
            .filter_map(|e| e.ok().map(|e| e.path()))
            .collect();
        entries.sort_by(|a, b| {
            a.file_name()
                .unwrap_or_default()
                .cmp(b.file_name().unwrap_or_default())
        });
        for entry in entries {
            let name = entry
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| "_".into());
            write_str(out, "entry");
            write_str(out, "(");
            write_str(out, "name");
            write_str(out, &name);
            write_str(out, "node");
            serialize_path(&entry, out)?;
            write_str(out, ")");
        }
    } else {
        // Regular file (and unusual unix types: fifo/socket/device treated as regular).
        write_str(out, "regular");
        let mode = meta.permissions().mode();
        if mode & 0o111 != 0 {
            write_str(out, "executable");
            write_str(out, "");
        }
        write_str(out, "contents");
        let data = fs::read(path).map_err(|e| InfraError::Io {
            path: path.display().to_string(),
            message: e.to_string(),
        })?;
        write_padded(out, &data);
    }

    write_str(out, ")");
    Ok(())
}

/// Serialize `path` as a Nix Archive into `out`.
pub fn nar_serialize(path: &Path, out: &mut Vec<u8>) -> Result<(), InfraError> {
    write_str(out, "nix-archive-1");
    serialize_path(path, out)
}

/// SHA256 of the NAR of `path` (Nix `outputHashMode = "recursive"`).
pub fn hash_path_recursive(path: &Path) -> Result<[u8; 32], InfraError> {
    let mut nar = Vec::new();
    nar_serialize(path, &mut nar)?;
    let dig = Sha256::digest(&nar);
    let mut out = [0u8; 32];
    out.copy_from_slice(&dig);
    Ok(out)
}

/// Convenience: write NAR bytes (used by tests).
pub fn nar_bytes(path: &Path) -> Result<Vec<u8>, InfraError> {
    let mut out = Vec::new();
    nar_serialize(path, &mut out)?;
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hash_parse::format_nix32;
    use crate::ingest::hash_flat_bytes;

    fn fixture_nar_tree() -> PathBuf {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
        assert!(dir.is_dir(), "missing fixture {dir:?}");
        dir
    }

    #[test]
    fn golden_recursive_matches_nix_hash() {
        let root = fixture_nar_tree();
        let dig = hash_path_recursive(&root).unwrap();
        assert_eq!(
            hex::encode(dig),
            "9d1ecf78f5e63c166734d9c5f2f4faf9fe3b116adc3dfa0721e1f2fd38120234"
        );
        assert_eq!(
            format_nix32(&dig),
            "0d0228wgvwp1443zlgfwd88kpzprzbsg5ifr6ikicg76ymwcy7lx"
        );
    }

    #[test]
    fn flat_differs_from_recursive_for_tree() {
        // Flat-hash of a directory isn't meaningful the same way; compare
        // recursive digest of tree vs flat of a single contained file.
        let root = fixture_nar_tree();
        let file = root.join("a/x");
        let flat = hash_flat_bytes(&fs::read(&file).unwrap());
        let rec = hash_path_recursive(&root).unwrap();
        assert_ne!(flat, rec);
    }

    #[test]
    fn nar_single_file() {
        let dir = std::env::temp_dir().join(format!("nixfetch-nar-file-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("f");
        fs::write(&path, b"hello").unwrap();
        let dig = hash_path_recursive(&path).unwrap();
        // Sanity: NAR of a file != flat hash of contents.
        assert_ne!(hex::encode(dig), hex::encode(hash_flat_bytes(b"hello")));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn nar_bytes_non_empty() {
        let root = fixture_nar_tree();
        let bytes = nar_bytes(&root).unwrap();
        assert!(!bytes.is_empty());
    }
}
