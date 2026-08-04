//! Content-addressed store path computation (no FS NAR walker).

use sha2::{Digest, Sha256};

use crate::error::ParseError;
use crate::hash::{compress_hash, nix_base32_encode};
use crate::store_path::StorePath;

/// How a fixed-output path was produced (flat file vs recursive NAR hash).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileIngestionMethod {
    Flat,
    Recursive,
}

/// Build a store path hash from type, hex hash, store dir, and name (Nix `make_store_path`).
pub fn make_store_path(type_str: &str, hash_hex: &str, name: &str, store_dir: &str) -> StorePath {
    let s = format!("{type_str}:{hash_hex}:{store_dir}:{name}");
    let digest = Sha256::digest(s.as_bytes());
    let compressed = compress_hash(&digest);
    StorePath {
        hash: nix_base32_encode(&compressed),
        name: name.to_string(),
    }
}

/// Fixed-output path for flat or recursive source (hash already known).
pub fn fixed_output_path(
    name: &str,
    method: FileIngestionMethod,
    hash_algo: &str,
    digest_bytes: &[u8],
    store_dir: &str,
) -> Result<StorePath, ParseError> {
    let _ = method;
    if hash_algo != "sha256" {
        return Err(ParseError::Invalid {
            offset: 0,
            what: "hash_algo".into(),
            message: format!("unsupported algo {hash_algo}"),
        });
    }
    let hash_hex = hex::encode(digest_bytes);
    Ok(make_store_path("source", &hash_hex, name, store_dir))
}

/// Text content-addressed path with sorted references (Nix text CA).
pub fn text_path(
    name: &str,
    digest_hex: &str,
    references: &[String],
    store_dir: &str,
) -> StorePath {
    let mut refs = references.to_vec();
    refs.sort();
    let hash_part = if refs.is_empty() {
        digest_hex.to_string()
    } else {
        format!("{digest_hex},{}", refs.join(","))
    };
    make_store_path("text", &hash_part, name, store_dir)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store_path::{DEFAULT_STORE_DIR, parse_store_path};
    use rstest::rstest;

    #[test]
    fn make_store_path_roundtrip_format() {
        let sp = make_store_path("source", "deadbeef", "hello-1.0", DEFAULT_STORE_DIR);
        let full = sp.full_path(DEFAULT_STORE_DIR);
        let parsed = parse_store_path(&full, DEFAULT_STORE_DIR).unwrap();
        assert_eq!(parsed.hash, sp.hash);
        assert_eq!(parsed.name, sp.name);
        assert_eq!(sp.hash.len(), 32);
    }

    #[rstest]
    #[case(FileIngestionMethod::Flat)]
    #[case(FileIngestionMethod::Recursive)]
    fn fixed_output_path_flat_and_recursive(#[case] method: FileIngestionMethod) {
        let digest = [0x11; 32];
        let sp = fixed_output_path("pkg", method, "sha256", &digest, DEFAULT_STORE_DIR).unwrap();
        assert_eq!(sp.name, "pkg");
        assert_eq!(sp.hash.len(), 32);
    }

    #[test]
    fn text_path_with_references() {
        let refs = vec!["/nix/store/a".into(), "/nix/store/b".into()];
        let sp = text_path("t", "abc123", &refs, DEFAULT_STORE_DIR);
        assert_eq!(sp.name, "t");
        let sp2 = text_path("t", "abc123", &refs, DEFAULT_STORE_DIR);
        assert_eq!(sp.hash, sp2.hash);
    }

    #[test]
    fn fixed_output_rejects_unknown_algo() {
        let err = fixed_output_path(
            "x",
            FileIngestionMethod::Flat,
            "md5",
            &[0],
            DEFAULT_STORE_DIR,
        )
        .unwrap_err();
        assert!(matches!(err, ParseError::Invalid { .. }));
    }
}
