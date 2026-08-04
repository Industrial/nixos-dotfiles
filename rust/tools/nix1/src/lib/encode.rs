//! Encodings and truncation matching stock `nix-hash`.

use base64::Engine;
use nixdrv::{NIX_BASE32_ALPHABET, compress_hash};

use crate::algo::HashAlgo;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Encoding {
    #[default]
    Base16,
    Base32,
    Base64,
    Sri,
}

/// Nix `Hash::base32Len()` = ceil(bits / 5).
pub fn nix_base32_len(byte_len: usize) -> usize {
    if byte_len == 0 {
        return 0;
    }
    (byte_len * 8 - 1) / 5 + 1
}

/// Characters accepted by Nix's base-32 alphabet (`NIX_BASE32_ALPHABET`).
pub fn is_nix_base32_char(c: char) -> bool {
    NIX_BASE32_ALPHABET.contains(c)
}

/// Nix `printHash32` (src/libutil/hash.cc).
pub fn nix_base32_encode_full(data: &[u8]) -> String {
    let alphabet = NIX_BASE32_ALPHABET.as_bytes();
    let len = nix_base32_len(data.len());
    let mut out = String::with_capacity(len);
    for n in (0..len).rev() {
        let b = n * 5;
        let i = b / 8;
        let j = b % 8;
        let mut c = u32::from(data[i]) >> j;
        if i < data.len() - 1 {
            c |= u32::from(data[i + 1]) << (8 - j);
        }
        out.push(alphabet[(c & 0x1f) as usize] as char);
    }
    out
}

/// Inverse of [`nix_base32_encode_full`] (Nix `Hash` nix32 parse).
pub fn nix_base32_decode_full(encoded: &str, byte_len: usize) -> Result<Vec<u8>, String> {
    let alphabet = NIX_BASE32_ALPHABET;
    let expected = nix_base32_len(byte_len);
    if encoded.len() != expected {
        return Err(format!(
            "invalid base-32 length {}, expect {expected} for {byte_len}-byte digest",
            encoded.len()
        ));
    }
    let mut out = vec![0u8; byte_len];
    for (n, ch) in encoded.chars().rev().enumerate() {
        let digit = alphabet
            .find(ch)
            .ok_or_else(|| format!("invalid base32 char {ch:?}"))? as u8;
        let b = n * 5;
        let i = b / 8;
        let j = b % 8;
        out[i] |= digit << j;
        if i < byte_len - 1 {
            if j != 0 {
                out[i + 1] |= digit >> (8 - j);
            }
        } else if j != 0 && digit >> (8 - j) != 0 {
            return Err("invalid base-32 hash".into());
        }
    }
    Ok(out)
}

pub fn maybe_truncate(digest: &[u8], truncate: bool) -> Vec<u8> {
    if truncate && digest.len() > 20 {
        compress_hash(digest).to_vec()
    } else {
        digest.to_vec()
    }
}

pub fn format_digest(algo: HashAlgo, digest: &[u8], encoding: Encoding) -> String {
    match encoding {
        Encoding::Base16 => hex::encode(digest),
        Encoding::Base32 => nix_base32_encode_full(digest),
        Encoding::Base64 => base64::engine::general_purpose::STANDARD.encode(digest),
        Encoding::Sri => {
            let b64 = base64::engine::general_purpose::STANDARD.encode(digest);
            format!("{}-{b64}", algo.as_str())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha1_base32_matches_nix_hash() {
        let dig = hex::decode("e4fd8ba5f7bbeaea5ace89fe10255536cd60dab6").unwrap();
        assert_eq!(nix_base32_encode_full(&dig), "nvd61k9nalji1zl9rrdfmsmvyyjqpzg4");
    }

    #[test]
    fn sha256_base32_matches_nix_hash() {
        let dig =
            hex::decode("0a430879c266f8b57f4092a0f935cf3facd48bbccde5760d4748ca405171e969").unwrap();
        assert_eq!(
            nix_base32_encode_full(&dig),
            "0sg9f58l1jj88w6pdrfdpj5x9b1zrwszk84j81zvby36q9whhhqa"
        );
    }

    #[test]
    fn truncate_is_compress_hash() {
        let dig =
            hex::decode("0a430879c266f8b57f4092a0f935cf3facd48bbccde5760d4748ca405171e969").unwrap();
        assert_eq!(
            hex::encode(maybe_truncate(&dig, true)),
            "c7a67e74852e32f52e317bc9f935cf3facd48bbc"
        );
    }
}
