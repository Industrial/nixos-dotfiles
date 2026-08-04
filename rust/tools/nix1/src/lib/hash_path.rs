//! Path hashing: flat file bytes or recursive NAR.

use std::fs;
use std::path::Path;

use nixfetch::nar_bytes;

use crate::algo::HashAlgo;
use crate::error::HashError;

pub fn hash_path(path: &Path, algo: HashAlgo, flat: bool) -> Result<Vec<u8>, HashError> {
    let bytes = if flat {
        fs::read(path).map_err(|e| HashError::Io {
            path: path.display().to_string(),
            message: e.to_string(),
        })?
    } else {
        nar_bytes(path).map_err(|e| HashError::Nar(e.to_string()))?
    };
    Ok(algo.digest(&bytes))
}
