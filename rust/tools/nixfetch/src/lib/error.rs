//! Error types for nixfetch.

use thiserror::Error;

/// Infra / domain failures — map to Fail / non-zero exit.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum InfraError {
    #[error("io error at {path}: {message}")]
    Io { path: String, message: String },
    #[error("http error for {url}: {message}")]
    Http { url: String, message: String },
    #[error("git error: {0}")]
    Git(String),
    #[error("parse error: {0}")]
    Parse(String),
    #[error("hash mismatch: expected {expected}, got {actual}")]
    HashMismatch { expected: String, actual: String },
    #[error("json error: {0}")]
    Json(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_variants() {
        assert!(InfraError::Io {
            path: "p".into(),
            message: "m".into()
        }
        .to_string()
        .contains("io error"));
        assert!(InfraError::Http {
            url: "u".into(),
            message: "m".into()
        }
        .to_string()
        .contains("http"));
        assert!(InfraError::Git("g".into()).to_string().contains("git"));
        assert!(InfraError::Parse("p".into()).to_string().contains("parse"));
        assert!(InfraError::HashMismatch {
            expected: "a".into(),
            actual: "b".into()
        }
        .to_string()
        .contains("mismatch"));
        assert!(InfraError::Json("j".into()).to_string().contains("json"));
    }
}
