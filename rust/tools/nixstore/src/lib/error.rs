//! Error types for nixstore.

use thiserror::Error;

/// Infra failures — map to Fail / non-zero exit.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum InfraError {
    #[error("io error at {path}: {message}")]
    Io { path: String, message: String },
    #[error("sqlite error: {0}")]
    Sqlite(String),
    #[error("database not found at {0}")]
    DbMissing(String),
    #[error("unknown store path: {0}")]
    UnknownPath(String),
    #[error("invalid hash in database: {0}")]
    InvalidHash(String),
    #[error("json error: {0}")]
    Json(String),
    #[error("schema error: {0}")]
    Schema(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_variants() {
        assert!(InfraError::Sqlite("x".into()).to_string().contains("sqlite"));
        assert!(InfraError::DbMissing("/tmp/db".into())
            .to_string()
            .contains("not found"));
        assert!(InfraError::UnknownPath("/nix/store/x".into())
            .to_string()
            .contains("unknown"));
        assert!(InfraError::InvalidHash("bad".into())
            .to_string()
            .contains("hash"));
        assert!(InfraError::Json("j".into()).to_string().contains("json"));
        assert!(InfraError::Schema("s".into()).to_string().contains("schema"));
        let io = InfraError::Io {
            path: "p".into(),
            message: "m".into(),
        };
        assert!(io.to_string().contains("io error"));
    }
}
