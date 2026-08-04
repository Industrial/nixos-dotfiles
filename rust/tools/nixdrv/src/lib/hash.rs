//! Nix base32 encoding and hash compression.

use crate::error::ParseError;

/// Nix base32 alphabet (no e, o, t, u).
pub const NIX_BASE32_ALPHABET: &str = "0123456789abcdfghijklmnpqrsvwxyz";

const HASH_LEN: usize = 20;
const HASH_STR_LEN: usize = 32;

pub fn nix_base32_encode(data: &[u8]) -> String {
    assert_eq!(data.len(), HASH_LEN);
    let alphabet = NIX_BASE32_ALPHABET.as_bytes();
    let mut out = String::with_capacity(HASH_STR_LEN);
    let mut bits: u32 = 0;
    let mut bit_count = 0u32;
    for &byte in data {
        bits = (bits << 8) | u32::from(byte);
        bit_count += 8;
        while bit_count >= 5 {
            bit_count -= 5;
            let idx = ((bits >> bit_count) & 0x1f) as usize;
            out.push(alphabet[idx] as char);
        }
    }
    if bit_count > 0 {
        let idx = ((bits << (5 - bit_count)) & 0x1f) as usize;
        out.push(alphabet[idx] as char);
    }
    while out.len() < HASH_STR_LEN {
        out.push('0');
    }
    out.truncate(HASH_STR_LEN);
    out
}

pub fn nix_base32_decode(encoded: &str) -> Result<[u8; HASH_LEN], ParseError> {
    if encoded.len() != HASH_STR_LEN {
        return Err(ParseError::Invalid {
            offset: 0,
            what: "base32".into(),
            message: format!("expected {HASH_STR_LEN} chars, got {}", encoded.len()),
        });
    }
    let mut out = [0u8; HASH_LEN];
    let mut bits: u32 = 0;
    let mut bit_count = 0u32;
    let mut o = 0usize;
    for (i, ch) in encoded.chars().enumerate() {
        let val = NIX_BASE32_ALPHABET
            .find(ch)
            .ok_or_else(|| ParseError::Invalid {
                offset: i,
                what: "base32".into(),
                message: format!("invalid char {ch:?}"),
            })? as u32;
        bits = (bits << 5) | val;
        bit_count += 5;
        if bit_count >= 8 {
            bit_count -= 8;
            if o < HASH_LEN {
                out[o] = ((bits >> bit_count) & 0xff) as u8;
                o += 1;
            }
        }
    }
    Ok(out)
}

/// XOR-fold a digest to 20 bytes (Nix `compressHash`).
pub fn compress_hash(hash: &[u8]) -> [u8; HASH_LEN] {
    let mut out = [0u8; HASH_LEN];
    for (j, slot) in out.iter_mut().enumerate() {
        let mut n = 0u8;
        let mut i = j;
        while i < hash.len() {
            n ^= hash[i];
            i += HASH_LEN;
        }
        *slot = n;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encode_decode_roundtrip() {
        let data = [0xab; HASH_LEN];
        let enc = nix_base32_encode(&data);
        assert_eq!(enc.len(), HASH_STR_LEN);
        let dec = nix_base32_decode(&enc).unwrap();
        assert_eq!(dec, data);
    }

    #[test]
    fn compress_hash_xor_fold() {
        let digest = [0u8; 32];
        let c = compress_hash(&digest);
        assert_eq!(c, [0u8; HASH_LEN]);
        let mut varied = [0u8; 32];
        varied[20] = 0xff;
        let c2 = compress_hash(&varied);
        assert_eq!(c2[0], 0xff);
    }

    #[test]
    fn rejects_invalid_base32_char() {
        let mut bad = "0".repeat(HASH_STR_LEN);
        bad.replace_range(0..1, "e");
        assert!(nix_base32_decode(&bad).is_err());
    }
}
