//! Nix store path parsing and display.

use std::fmt;

use crate::error::ParseError;

pub const DEFAULT_STORE_DIR: &str = "/nix/store";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StorePath {
    pub hash: String,
    pub name: String,
}

impl StorePath {
    pub fn full_path(&self, store_dir: &str) -> String {
        format!("{store_dir}/{}-{}", self.hash, self.name)
    }
}

impl fmt::Display for StorePath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}/{}", self.hash, self.name)
    }
}

pub fn parse_store_path(s: &str, store_dir: &str) -> Result<StorePath, ParseError> {
    let prefix = format!("{store_dir}/");
    let rest = s.strip_prefix(&prefix).ok_or_else(|| ParseError::Invalid {
        offset: 0,
        what: "store path".into(),
        message: format!("expected prefix {prefix}"),
    })?;
    let (hash, name) = rest.split_once('-').ok_or_else(|| ParseError::Invalid {
        offset: prefix.len(),
        what: "store path".into(),
        message: "missing name separator".into(),
    })?;
    if hash.len() != 32 || !hash.chars().all(is_nix_base32_char) {
        return Err(ParseError::Invalid {
            offset: prefix.len(),
            what: "hash".into(),
            message: format!("expected 32 nix-base32 chars, got {}", hash.len()),
        });
    }
    if name.is_empty() {
        return Err(ParseError::Invalid {
            offset: prefix.len() + hash.len() + 1,
            what: "name".into(),
            message: "empty name".into(),
        });
    }
    Ok(StorePath {
        hash: hash.to_string(),
        name: name.to_string(),
    })
}

fn is_nix_base32_char(c: char) -> bool {
    matches!(
        c,
        '0'..='9'
            | 'a'..='d'
            | 'f'
            | 'g'
            | 'h'
            | 'i'
            | 'j'
            | 'k'
            | 'l'
            | 'm'
            | 'n'
            | 'p'
            | 'q'
            | 'r'
            | 's'
            | 'v'
            | 'w'
            | 'x'
            | 'y'
            | 'z'
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_and_display_roundtrip() {
        let s = "/nix/store/00000000000000000000000000000000-hello-1.0";
        let sp = parse_store_path(s, DEFAULT_STORE_DIR).unwrap();
        assert_eq!(sp.hash, "00000000000000000000000000000000");
        assert_eq!(sp.name, "hello-1.0");
        assert_eq!(sp.full_path(DEFAULT_STORE_DIR), s);
    }

    #[test]
    fn rejects_bad_prefix() {
        assert!(parse_store_path("/tmp/foo", DEFAULT_STORE_DIR).is_err());
    }

    #[test]
    fn rejects_short_hash() {
        let s = "/nix/store/abc-name";
        assert!(parse_store_path(s, DEFAULT_STORE_DIR).is_err());
    }
}
