//! Hash algorithm selection for `nix-hash`.

use md5::{Digest as _, Md5};
use sha1::Sha1;
use sha2::{Sha256, Sha512};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HashAlgo {
    Md5,
    Sha1,
    Sha256,
    Sha512,
    Blake3,
}

impl HashAlgo {
    pub fn parse(s: &str) -> Result<Self, String> {
        match s {
            "md5" => Ok(Self::Md5),
            "sha1" => Ok(Self::Sha1),
            "sha256" => Ok(Self::Sha256),
            "sha512" => Ok(Self::Sha512),
            "blake3" => Ok(Self::Blake3),
            other => Err(format!(
                "unknown hash algorithm '{other}', expect blake3|md5|sha1|sha256|sha512"
            )),
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Md5 => "md5",
            Self::Sha1 => "sha1",
            Self::Sha256 => "sha256",
            Self::Sha512 => "sha512",
            Self::Blake3 => "blake3",
        }
    }

    pub fn digest_len(self) -> usize {
        match self {
            Self::Md5 => 16,
            Self::Sha1 => 20,
            Self::Sha256 | Self::Blake3 => 32,
            Self::Sha512 => 64,
        }
    }

    pub fn digest(self, data: &[u8]) -> Vec<u8> {
        match self {
            Self::Md5 => Md5::digest(data).to_vec(),
            Self::Sha1 => Sha1::digest(data).to_vec(),
            Self::Sha256 => Sha256::digest(data).to_vec(),
            Self::Sha512 => Sha512::digest(data).to_vec(),
            Self::Blake3 => blake3::hash(data).as_bytes().to_vec(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flat_md5_hello() {
        assert_eq!(
            hex::encode(HashAlgo::Md5.digest(b"hello")),
            "5d41402abc4b2a76b9719d911017c592"
        );
    }

    #[test]
    fn flat_sha256_hello() {
        assert_eq!(
            hex::encode(HashAlgo::Sha256.digest(b"hello")),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }
}
