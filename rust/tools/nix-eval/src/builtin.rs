//! Builtin function trait

use crate::error::Result;
use crate::value::NixValue;

/// Trait for builtin functions that can be called during evaluation
///
/// Implement this trait to provide custom builtin functions to the evaluator.
///
/// # Example
///
/// ```no_run
/// use nix_eval::{Builtin, NixValue, Result};
///
/// struct AddBuiltin;
///
/// impl Builtin for AddBuiltin {
///     fn name(&self) -> &str {
///         "add"
///     }
///
///     fn call(&self, args: &[NixValue]) -> Result<NixValue> {
///         if args.len() != 2 {
///             return Err(nix_eval::Error::UnsupportedExpression {
///                 reason: "add requires 2 arguments".to_string(),
///             });
///         }
///         // Implementation...
///         Ok(NixValue::Integer(0))
///     }
/// }
/// ```
pub trait Builtin: Send + Sync {
    /// Returns the name of the builtin function
    fn name(&self) -> &str;

    /// Calls the builtin function with the given arguments
    ///
    /// # Arguments
    ///
    /// * `args` - Slice of evaluated argument values
    ///
    /// # Returns
    ///
    /// The result of the builtin function call, or an error
    fn call(&self, args: &[NixValue]) -> Result<NixValue>;
}
