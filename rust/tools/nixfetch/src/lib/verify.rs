//! Verify helpers and store-path projection.

use nixdrv::{FileIngestionMethod, StorePath, DEFAULT_STORE_DIR, fixed_output_path};

use crate::error::InfraError;
use crate::hash_parse::{ExpectedHash, format_digest, format_hex, format_nix32, verify_digest};

pub fn make_fixed_output_path(
    name: &str,
    recursive: bool,
    digest: &[u8; 32],
    store_dir: Option<&str>,
) -> Result<StorePath, InfraError> {
    let method = if recursive {
        FileIngestionMethod::Recursive
    } else {
        FileIngestionMethod::Flat
    };
    fixed_output_path(
        name,
        method,
        "sha256",
        digest,
        store_dir.unwrap_or(DEFAULT_STORE_DIR),
    )
    .map_err(|e| InfraError::Parse(e.to_string()))
}

pub fn digest_report(digest: &[u8; 32]) -> serde_json::Map<String, serde_json::Value> {
    let mut m = serde_json::Map::new();
    m.insert("sri".into(), serde_json::Value::String(format_digest(digest)));
    m.insert("nix32".into(), serde_json::Value::String(format_nix32(digest)));
    m.insert("hex".into(), serde_json::Value::String(format_hex(digest)));
    m
}

pub fn verify_or_err(expected: &ExpectedHash, actual: &[u8; 32]) -> Result<(), InfraError> {
    verify_digest(expected, actual)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hash_parse::parse_expected_hash;
    use crate::ingest::hash_flat_bytes;

    #[test]
    fn store_path_from_hello() {
        let dig = hash_flat_bytes(b"hello");
        let sp = make_fixed_output_path("pkg", false, &dig, None).unwrap();
        assert_eq!(sp.name, "pkg");
        assert_eq!(sp.hash.len(), 32);
    }

    #[test]
    fn verify_helper() {
        let dig = hash_flat_bytes(b"hello");
        let exp = parse_expected_hash(&format_digest(&dig)).unwrap();
        verify_or_err(&exp, &dig).unwrap();
        let report = digest_report(&dig);
        assert!(report.get("sri").is_some());
    }
}
