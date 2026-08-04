//! Convert modes: `--to-base16|32|64|sri`.

use crate::algo::HashAlgo;
use crate::encode::{Encoding, format_digest, nix_base32_decode_full};
use crate::error::HashError;

pub fn convert_hash(
    input: &str,
    algo: HashAlgo,
    to: Encoding,
    from_is_base32: bool,
) -> Result<String, HashError> {
    let digest = if from_is_base32 {
        nix_base32_decode_full(input, algo.digest_len()).map_err(HashError::Convert)?
    } else {
        hex::decode(input).map_err(|e| HashError::Convert(e.to_string()))?
    };
    Ok(format_digest(algo, &digest, to))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::encode::nix_base32_encode_full;

    #[test]
    fn to_sri_from_hex_sha256() {
        let hex = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824";
        let out = convert_hash(hex, HashAlgo::Sha256, Encoding::Sri, false).unwrap();
        assert_eq!(out, "sha256-LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=");
    }

    #[test]
    fn roundtrip_base32_to_hex_sha1() {
        let b32 = "nvd61k9nalji1zl9rrdfmsmvyyjqpzg4";
        let out = convert_hash(b32, HashAlgo::Sha1, Encoding::Base16, true).unwrap();
        assert_eq!(out, "e4fd8ba5f7bbeaea5ace89fe10255536cd60dab6");
        let back = nix_base32_encode_full(&hex::decode(&out).unwrap());
        assert_eq!(back, b32);
    }
}
