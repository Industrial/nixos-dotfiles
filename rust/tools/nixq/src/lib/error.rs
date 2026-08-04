//! Error types for nixq.

use thiserror::Error;

/// Infra failures (I/O, JSON parse) — map to Fail / non-predicate exit.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum InfraError {
    #[error("io error at {path}: {message}")]
    Io { path: String, message: String },
    #[error("json parse error: {0}")]
    Json(String),
}

/// Attrpath parse / resolve failures.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum PathError {
    #[error("invalid attrpath: {0}")]
    Invalid(String),
    #[error("path not found: {0}")]
    NotFound(String),
}

/// Predicate CLI outcome (exit 0 / 1).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PredicateResult {
    True,
    False,
}

impl PredicateResult {
    pub fn as_bool(self) -> bool {
        matches!(self, Self::True)
    }

    pub fn from_bool(v: bool) -> Self {
        if v { Self::True } else { Self::False }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn predicate_and_display() {
        assert!(PredicateResult::True.as_bool());
        assert!(!PredicateResult::False.as_bool());
        assert_eq!(PredicateResult::from_bool(true), PredicateResult::True);
        assert_eq!(PredicateResult::from_bool(false), PredicateResult::False);
        let io = InfraError::Io {
            path: "p".into(),
            message: "m".into(),
        };
        assert!(io.to_string().contains("io error"));
        assert!(InfraError::Json("x".into()).to_string().contains("json"));
        assert!(PathError::Invalid("i".into()).to_string().contains("invalid"));
        assert!(PathError::NotFound("n".into()).to_string().contains("not found"));
    }
}
