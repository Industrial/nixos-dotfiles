//! Library entry used by `nix1-hash` binary.

use std::path::Path;

use crate::algo::HashAlgo;
use crate::convert::convert_hash;
use crate::encode::{Encoding, format_digest, maybe_truncate};
use crate::error::HashError;
use crate::hash_path::hash_path;

pub fn run_hash_paths(
    paths: &[impl AsRef<Path>],
    algo: HashAlgo,
    flat: bool,
    truncate: bool,
    encoding: Encoding,
) -> Result<Vec<String>, HashError> {
    let mut lines = Vec::with_capacity(paths.len());
    for p in paths {
        let dig = hash_path(p.as_ref(), algo, flat)?;
        let dig = maybe_truncate(&dig, truncate);
        lines.push(format_digest(algo, &dig, encoding));
    }
    Ok(lines)
}

pub fn run_convert(
    hashes: &[String],
    algo: HashAlgo,
    to: Encoding,
) -> Result<Vec<String>, HashError> {
    let from_base32 = matches!(to, Encoding::Base16);
    let mut lines = Vec::with_capacity(hashes.len());
    for h in hashes {
        lines.push(convert_hash(h, algo, to, from_base32)?);
    }
    Ok(lines)
}
