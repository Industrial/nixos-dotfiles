//! Error types for Nix evaluation
//!
//! All errors follow the "cannot" prefix convention for user-facing messages.

use thiserror::Error;

/// Error type for Nix evaluation
///
/// All errors follow the "cannot" prefix convention for user-facing messages.
///
/// # Example
///
/// ```no_run
/// use nix_eval::{Evaluator, Error};
///
/// let evaluator = Evaluator::new();
/// match evaluator.evaluate("invalid syntax {") {
///     Err(Error::ParseError { reason }) => {
///         println!("Parse error: {}", reason);
///     }
///     _ => {}
/// }
/// ```
#[derive(Debug, Error)]
pub enum Error {
    /// Parse error occurred when tokenizing or parsing the Nix expression
    #[error("cannot parse nix expression: {reason}")]
    ParseError { reason: String },

    /// Failed to convert parsed syntax tree to AST root
    #[error("cannot convert to AST root")]
    AstConversionError,

    /// No expression found in the parsed input
    #[error("no expression found")]
    NoExpression,

    /// Expression type is not supported by the evaluator
    ///
    /// This typically occurs when encountering expressions like function calls,
    /// variable references, or other advanced Nix features that are not yet implemented.
    #[error("cannot evaluate unsupported expression type: {reason}")]
    UnsupportedExpression { reason: String },

    /// Literal value could not be parsed or is unsupported
    #[error("cannot evaluate unsupported literal: {literal}")]
    UnsupportedLiteral { literal: String },

    /// Infinite recursion detected (blackhole)
    ///
    /// This error occurs when a thunk tries to evaluate itself while it's already
    /// being evaluated, indicating infinite recursion. The blackhole marker prevents
    /// stack overflow by detecting this condition early.
    #[error("infinite recursion detected: thunk is already being evaluated (blackhole)")]
    InfiniteRecursion,

    /// IO error occurred during file operations
    #[error("io error: {0}")]
    IoError(#[from] std::io::Error),
}

/// Result type alias for the library
///
/// All library functions return `Result<T, Error>` where `T` is the success type.
///
/// # Example
///
/// ```no_run
/// use nix_eval::{Evaluator, Result};
///
/// fn evaluate_safely(expr: &str) -> Result<()> {
///     let evaluator = Evaluator::new();
///     let _value = evaluator.evaluate(expr)?;
///     Ok(())
/// }
/// ```
pub type Result<T> = std::result::Result<T, Error>;
