//! Parse and format expected/actual SHA256 digests (SRI, hex, Nix base32).

use base64::Engine;
use base64::engine::general_purpose::STANDARD as B64;
use nixdrv::{NIX_BASE32_ALPHABET, compress_hash, nix_base32_decode};

use crate::error::InfraError;

/// Expected hash supplied by the user or a FOD declaration.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExpectedHash {
    /// Full 32-byte SHA256 (from hex, SRI, or 52-char nix32).
    Digest([u8; 32]),
    /// Compressed 20-byte / 32-char Nix base32 form (store-path style).
    Compressed([u8; 20]),
}

/// Nix `printHash32`-style encode for arbitrary digests (e.g. 52 chars for sha256).
pub fn nix32_encode_bytes(data: &[u8]) -> String {
    let alphabet = NIX_BASE32_ALPHABET.as_bytes();
    let len_chars = (data.len() * 8).div_ceil(5);
    let mut out = Vec::with_capacity(len_chars);
    for n in (0..len_chars).rev() {
        let b = n * 5;
        let i = b / 8;
        let j = b % 8;
        let mut c = u32::from(data[i]) >> j;
        if i + 1 < data.len() {
            c |= u32::from(data[i + 1]) << (8 - j);
        }
        out.push(alphabet[(c & 0x1f) as usize]);
    }
    // SAFETY: alphabet is ASCII
    String::from_utf8(out).expect("nix alphabet is ascii")
}

/// Decode 52-char nix32 → 32-byte digest (inverse of [`nix32_encode_bytes`]).
pub fn nix32_decode_digest(encoded: &str) -> Result<[u8; 32], InfraError> {
    const DIGEST_LEN: usize = 32;
    const STR_LEN: usize = 52;
    if encoded.len() != STR_LEN {
        return Err(InfraError::Parse(format!(
            "expected {STR_LEN}-char nix32 digest, got {}",
            encoded.len()
        )));
    }
    let mut out = [0u8; DIGEST_LEN];
    for (n, ch) in encoded.chars().rev().enumerate() {
        let val = NIX_BASE32_ALPHABET
            .find(ch)
            .ok_or_else(|| InfraError::Parse(format!("invalid nix32 char {ch:?}")))?
            as u32;
        let b = n * 5;
        let i = b / 8;
        let j = b % 8;
        out[i] |= ((val << j) & 0xff) as u8;
        if j > 3 && i + 1 < DIGEST_LEN {
            out[i + 1] |= (val >> (8 - j)) as u8;
        }
    }
    Ok(out)
}

/// Parse `sha256-…` SRI, 64-char hex, 52-char nix32 digest, or 32-char compressed nix32.
pub fn parse_expected_hash(input: &str) -> Result<ExpectedHash, InfraError> {
    let s = input.trim();
    if let Some(b64) = s.strip_prefix("sha256-") {
        let bytes = B64
            .decode(b64)
            .map_err(|e| InfraError::Parse(format!("invalid SRI base64: {e}")))?;
        let digest: [u8; 32] = bytes
            .try_into()
            .map_err(|_| InfraError::Parse("SRI sha256 must decode to 32 bytes".into()))?;
        return Ok(ExpectedHash::Digest(digest));
    }
    if s.len() == 64 && s.chars().all(|c| c.is_ascii_hexdigit()) {
        let bytes = hex::decode(s).map_err(|e| InfraError::Parse(format!("invalid hex: {e}")))?;
        let digest: [u8; 32] = bytes
            .try_into()
            .map_err(|_| InfraError::Parse("hex digest must be 32 bytes".into()))?;
        return Ok(ExpectedHash::Digest(digest));
    }
    if s.len() == 52 {
        return Ok(ExpectedHash::Digest(nix32_decode_digest(s)?));
    }
    if s.len() == 32 {
        let compressed = nix_base32_decode(s).map_err(|e| InfraError::Parse(e.to_string()))?;
        return Ok(ExpectedHash::Compressed(compressed));
    }
    Err(InfraError::Parse(format!(
        "unrecognised hash format (want SRI, 64-hex, 52-char nix32, or 32-char nix32): {s:?}"
    )))
}

/// Compare expected hash against a computed full digest.
pub fn verify_digest(expected: &ExpectedHash, actual: &[u8; 32]) -> Result<(), InfraError> {
    match expected {
        ExpectedHash::Digest(want) => {
            if want == actual {
                Ok(())
            } else {
                Err(InfraError::HashMismatch {
                    expected: format_digest(want),
                    actual: format_digest(actual),
                })
            }
        }
        ExpectedHash::Compressed(want) => {
            let got = compress_hash(actual);
            if want == &got {
                Ok(())
            } else {
                Err(InfraError::HashMismatch {
                    expected: nixdrv::nix_base32_encode(want),
                    actual: nixdrv::nix_base32_encode(&got),
                })
            }
        }
    }
}

pub fn format_digest(digest: &[u8; 32]) -> String {
    format!("sha256-{}", B64.encode(digest))
}

/// `nix-hash --base32` form (52 chars for sha256).
pub fn format_nix32(digest: &[u8; 32]) -> String {
    nix32_encode_bytes(digest)
}

pub fn format_hex(digest: &[u8; 32]) -> String {
    hex::encode(digest)
}

#[cfg(test)]
mod tests {
    use super::*;

    const HELLO_HEX: &str = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824";
    const HELLO_SRI: &str = "sha256-LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=";
    const HELLO_NIX32: &str = "094qif9n4cq4fdg459qzbhg1c6wywawwaaivx0k0x8xhbyx4vwic";

    fn hello_digest() -> [u8; 32] {
        let v = hex::decode(HELLO_HEX).unwrap();
        v.try_into().unwrap()
    }

    #[test]
    fn parse_sri_hex_nix32() {
        let d = hello_digest();
        assert_eq!(
            parse_expected_hash(HELLO_SRI).unwrap(),
            ExpectedHash::Digest(d)
        );
        assert_eq!(
            parse_expected_hash(HELLO_HEX).unwrap(),
            ExpectedHash::Digest(d)
        );
        assert_eq!(
            parse_expected_hash(HELLO_NIX32).unwrap(),
            ExpectedHash::Digest(d)
        );
        let compressed = compress_hash(&d);
        let enc32 = nixdrv::nix_base32_encode(&compressed);
        assert_eq!(
            parse_expected_hash(&enc32).unwrap(),
            ExpectedHash::Compressed(compressed)
        );
    }

    #[test]
    fn verify_ok_and_mismatch() {
        let d = hello_digest();
        verify_digest(&ExpectedHash::Digest(d), &d).unwrap();
        verify_digest(
            &ExpectedHash::Compressed(compress_hash(&d)),
            &d,
        )
        .unwrap();
        let other = [0u8; 32];
        assert!(matches!(
            verify_digest(&ExpectedHash::Digest(d), &other),
            Err(InfraError::HashMismatch { .. })
        ));
    }

    #[test]
    fn format_helpers() {
        let d = hello_digest();
        assert_eq!(format_digest(&d), HELLO_SRI);
        assert_eq!(format_nix32(&d), HELLO_NIX32);
        assert_eq!(format_hex(&d), HELLO_HEX);
        assert_eq!(nix32_decode_digest(HELLO_NIX32).unwrap(), d);
    }

    #[test]
    fn rejects_garbage() {
        assert!(parse_expected_hash("not-a-hash").is_err());
        assert!(parse_expected_hash("sha256-!!!").is_err());
    }
}
