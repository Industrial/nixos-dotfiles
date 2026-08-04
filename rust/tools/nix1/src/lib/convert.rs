//! Convert modes: `--to-base16|32|64|sri`.

//! Stock `nix-hash` accepts Nix `Hash::parseAny` input for `--to-*`:
//! hex, nix base32, SRI (`algo-…`), and typed prefixes (`algo:…`).

use base64::Engine;

use crate::algo::HashAlgo;
use crate::encode::{
    Encoding, format_digest, nix_base32_decode_full, nix_base32_len,
};
use crate::error::HashError;

/// Decode a convert-mode hash string into `(algo, digest)`.
///
/// `type_hint` is the CLI `--type` when present. Embedded type in the string
/// (SRI / `algo:`) wins and must agree with the hint when both exist.
pub fn parse_any_hash(
    input: &str,
    type_hint: Option<HashAlgo>,
) -> Result<(HashAlgo, Vec<u8>), HashError> {
    let s = input.trim();
    if s.is_empty() {
        return Err(HashError::Convert("empty hash".into()));
    }

    if let Some((algo_s, rest)) = s.split_once('-') {
        if looks_like_algo_name(algo_s) && !rest.is_empty() && !rest.contains(':') {
            // Prefer SRI when the algo token is a known hash name and the rest
            // is not a typed `algo:payload` (those use `:`).
            if rest.chars().all(|c| c.is_ascii_alphanumeric() || c == '+' || c == '/' || c == '=') {
                let algo = HashAlgo::parse(algo_s).map_err(HashError::Convert)?;
                check_hint(algo, type_hint)?;
                let bytes = base64::engine::general_purpose::STANDARD
                    .decode(rest)
                    .map_err(|e| HashError::Convert(format!("invalid SRI base64: {e}")))?;
                if bytes.len() != algo.digest_len() {
                    return Err(HashError::Convert(format!(
                        "hash '{s}' has wrong length for hash algorithm '{}'",
                        algo.as_str()
                    )));
                }
                return Ok((algo, bytes));
            }
        }
    }

    if let Some((algo_s, rest)) = s.split_once(':') {
        if looks_like_algo_name(algo_s) {
            let algo = HashAlgo::parse(algo_s).map_err(HashError::Convert)?;
            check_hint(algo, type_hint)?;
            let digest = decode_raw_for_algo(rest, algo)?;
            return Ok((algo, digest));
        }
    }

    let algo = type_hint.ok_or_else(|| {
        HashError::Convert(format!(
            "hash '{s}' does not include a type, nor is the type otherwise known from context"
        ))
    })?;
    Ok((algo, decode_raw_for_algo(s, algo)?))
}

fn looks_like_algo_name(s: &str) -> bool {
    matches!(s, "md5" | "sha1" | "sha256" | "sha512" | "blake3")
}

fn check_hint(algo: HashAlgo, hint: Option<HashAlgo>) -> Result<(), HashError> {
    if let Some(h) = hint {
        if h != algo {
            return Err(HashError::Convert(format!(
                "hash algorithm mismatch: string says '{}', --type says '{}'",
                algo.as_str(),
                h.as_str()
            )));
        }
    }
    Ok(())
}

fn decode_raw_for_algo(raw: &str, algo: HashAlgo) -> Result<Vec<u8>, HashError> {
    let want = algo.digest_len();
    let hex_len = want * 2;
    let b32_len = nix_base32_len(want);

    if raw.len() == hex_len && raw.chars().all(|c| c.is_ascii_hexdigit()) {
        return hex::decode(raw).map_err(|e| HashError::Convert(e.to_string()));
    }

    if raw.len() == b32_len && raw.chars().all(|c| crate::encode::is_nix_base32_char(c)) {
        return nix_base32_decode_full(raw, want).map_err(HashError::Convert);
    }

    // Bare standard base64 digest (rare; SRI without algo prefix handled above).
    if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(raw) {
        if bytes.len() == want {
            return Ok(bytes);
        }
    }

    // SRI form with --type already known: `sha256-…` still reaches here if
    // algo token check failed; try stripping matching prefix.
    let prefix = format!("{}-", algo.as_str());
    if let Some(b64) = raw.strip_prefix(&prefix) {
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(b64)
            .map_err(|e| HashError::Convert(format!("invalid SRI base64: {e}")))?;
        if bytes.len() == want {
            return Ok(bytes);
        }
    }

    Err(HashError::Convert(format!(
        "hash '{raw}' has wrong length for hash algorithm '{}'",
        algo.as_str()
    )))
}

pub fn convert_hash(
    input: &str,
    type_hint: Option<HashAlgo>,
    to: Encoding,
) -> Result<String, HashError> {
    let (algo, digest) = parse_any_hash(input, type_hint)?;
    Ok(format_digest(algo, &digest, to))
}

#[cfg(test)]
mod tests {
    use super::*;

    const HELLO_HEX: &str = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824";
    const HELLO_B32: &str = "094qif9n4cq4fdg459qzbhg1c6wywawwaaivx0k0x8xhbyx4vwic";
    const HELLO_SRI: &str = "sha256-LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=";

    #[test]
    fn to_sri_from_hex_sha256() {
        let out = convert_hash(HELLO_HEX, Some(HashAlgo::Sha256), Encoding::Sri).unwrap();
        assert_eq!(out, HELLO_SRI);
    }

    #[test]
    fn to_sri_from_base32_sha256() {
        let out = convert_hash(HELLO_B32, Some(HashAlgo::Sha256), Encoding::Sri).unwrap();
        assert_eq!(out, HELLO_SRI);
    }

    #[test]
    fn to_sri_from_prefixed_base32() {
        let out = convert_hash(
            &format!("sha256:{HELLO_B32}"),
            None,
            Encoding::Sri,
        )
        .unwrap();
        assert_eq!(out, HELLO_SRI);
    }

    #[test]
    fn to_sri_from_store_query_hash() {
        // nix-store --query --hash form used by bootstrap refresh-tarballs.
        let store = "sha256:0sg9f58l1jj88w6pdrfdpj5x9b1zrwszk84j81zvby36q9whhhqa";
        let out = convert_hash(store, None, Encoding::Sri).unwrap();
        assert_eq!(out, "sha256-CkMIecJm+LV/QJKg+TXPP6zUi7zN5XYNR0jKQFFx6Wk=");
    }

    #[test]
    fn to_base16_from_base32() {
        let out = convert_hash(HELLO_B32, Some(HashAlgo::Sha256), Encoding::Base16).unwrap();
        assert_eq!(out, HELLO_HEX);
    }

    #[test]
    fn to_base64_from_sri() {
        let out = convert_hash(HELLO_SRI, Some(HashAlgo::Sha256), Encoding::Base64).unwrap();
        assert_eq!(out, "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=");
    }

    #[test]
    fn missing_type_errors_like_stock() {
        let err = convert_hash(HELLO_HEX, None, Encoding::Sri).unwrap_err();
        assert!(err.to_string().contains("does not include a type"));
    }

    #[test]
    fn roundtrip_base32_to_hex_sha1() {
        let b32 = "nvd61k9nalji1zl9rrdfmsmvyyjqpzg4";
        let out = convert_hash(b32, Some(HashAlgo::Sha1), Encoding::Base16).unwrap();
        assert_eq!(out, "e4fd8ba5f7bbeaea5ace89fe10255536cd60dab6");
    }
}
