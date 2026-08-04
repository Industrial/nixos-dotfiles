//! Flat file/byte SHA256 hashing.

use std::path::Path;

use sha2::{Digest, Sha256};

use crate::error::InfraError;

pub fn hash_flat_bytes(bytes: &[u8]) -> [u8; 32] {
    let dig = Sha256::digest(bytes);
    let mut out = [0u8; 32];
    out.copy_from_slice(&dig);
    out
}

pub fn hash_flat_path(path: &Path) -> Result<[u8; 32], InfraError> {
    let bytes = std::fs::read(path).map_err(|e| InfraError::Io {
        path: path.display().to_string(),
        message: e.to_string(),
    })?;
    Ok(hash_flat_bytes(&bytes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_and_hello() {
        assert_eq!(
            hex::encode(hash_flat_bytes(b"")),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        assert_eq!(
            hex::encode(hash_flat_bytes(b"hello")),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }

    #[test]
    fn hash_flat_path_reads_file() {
        let dir = std::env::temp_dir().join(format!(
            "nixfetch-flat-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("hello");
        std::fs::write(&path, b"hello").unwrap();
        assert_eq!(
            hex::encode(hash_flat_path(&path).unwrap()),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn missing_path_errs() {
        assert!(matches!(
            hash_flat_path(Path::new("/no/such/nixfetch-file")),
            Err(InfraError::Io { .. })
        ));
    }
}
