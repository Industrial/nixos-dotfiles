//! Error types for nixdrv.

use thiserror::Error;

/// Infra failures (I/O, JSON parse) — map to Fail / non-zero exit.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum InfraError {
    #[error("io error at {path}: {message}")]
    Io { path: String, message: String },
    #[error("json parse error: {0}")]
    Json(String),
    #[error("parse error: {0}")]
    Parse(#[from] ParseError),
}

/// Derivation / ATerm parse failures.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum ParseError {
    #[error("unexpected token at offset {offset}: {message}")]
    Unexpected { offset: usize, message: String },
    #[error("unexpected end of input at offset {offset}")]
    Eof { offset: usize },
    #[error("invalid {what} at offset {offset}: {message}")]
    Invalid {
        offset: usize,
        what: String,
        message: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_roundtrip() {
        let io = InfraError::Io {
            path: "p".into(),
            message: "m".into(),
        };
        assert!(io.to_string().contains("io error"));
        assert!(InfraError::Json("x".into()).to_string().contains("json"));
        let pe = ParseError::Unexpected {
            offset: 1,
            message: "bad".into(),
        };
        assert!(InfraError::Parse(pe).to_string().contains("parse error"));
    }
}
