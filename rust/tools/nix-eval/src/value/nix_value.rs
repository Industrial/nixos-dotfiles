//! NixValue enum and basic operations

use crate::function;
use crate::thunk;
use crate::value::Derivation;
use serde::Serialize;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;

/// Represents a Nix value after evaluation
///
/// This enum covers all supported Nix value types. Values can be serialized to JSON
/// using the `Serialize` trait, or formatted as Nix code using the `Display` trait.
///
/// # Example
///
/// ```no_run
/// use nix_eval::{Evaluator, NixValue};
///
/// let evaluator = Evaluator::new();
/// let value = evaluator.evaluate(r#""hello""#).unwrap();
/// match value {
///     NixValue::String(s) => println!("Got string: {}", s),
///     _ => {}
/// }
/// ```
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", content = "value")]
pub enum NixValue {
    /// String value
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate(r#""hello world""#).unwrap();
    /// assert!(matches!(value, NixValue::String(_)));
    /// ```
    #[serde(rename = "string")]
    String(String),
    /// Integer value (64-bit signed)
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("42").unwrap();
    /// assert_eq!(value, NixValue::Integer(42));
    /// ```
    #[serde(rename = "integer")]
    Integer(i64),
    /// Floating-point value (64-bit)
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("3.14").unwrap();
    /// assert!(matches!(value, NixValue::Float(_)));
    /// ```
    #[serde(rename = "float")]
    Float(f64),
    /// Boolean value
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("true").unwrap();
    /// assert_eq!(value, NixValue::Boolean(true));
    /// ```
    #[serde(rename = "boolean")]
    Boolean(bool),
    /// Null value
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("null").unwrap();
    /// assert_eq!(value, NixValue::Null);
    /// ```
    #[serde(rename = "null")]
    Null,
    /// Attribute set (map of string keys to Nix values)
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("{ foo = 1; bar = 2; }").unwrap();
    /// assert!(matches!(value, NixValue::AttributeSet(_)));
    /// ```
    #[serde(rename = "attrset")]
    AttributeSet(HashMap<String, NixValue>),
    /// List of Nix values
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("[1 2 3]").unwrap();
    /// assert!(matches!(value, NixValue::List(_)));
    /// ```
    #[serde(rename = "list")]
    List(Vec<NixValue>),
    /// A thunk (lazy value) that will be evaluated when forced
    ///
    /// This represents a delayed computation. The thunk will be evaluated
    /// when its value is actually needed (lazy evaluation).
    #[serde(skip)]
    Thunk(Arc<thunk::Thunk>),
    /// A function (closure) that can be applied to arguments
    ///
    /// Functions are closures that capture their lexical environment (scope)
    /// and can be applied to arguments. When applied, the function body is
    /// evaluated with the argument bound to the function parameter.
    #[serde(skip)]
    Function(Arc<function::Function>),
    /// Path value (file system path)
    ///
    /// Path literals like `./file.nix` or `/absolute/path` represent file system paths.
    /// Paths can be used with the `import` builtin to load and evaluate Nix files.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("./file.nix").unwrap();
    /// assert!(matches!(value, NixValue::Path(_)));
    /// ```
    #[serde(rename = "path")]
    Path(PathBuf),
    /// Store path value (Nix store path)
    ///
    /// Store paths like `/nix/store/abc123-package-name` represent paths in the Nix store.
    /// Store paths have a specific format: `/nix/store/<hash>-<name>` where hash is a
    /// base32-encoded cryptographic hash and name is the rest of the path component.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// let value = evaluator.evaluate("/nix/store/abc123-package").unwrap();
    /// assert!(matches!(value, NixValue::StorePath(_)));
    /// ```
    #[serde(rename = "store_path")]
    StorePath(String),
    /// Derivation value (build plan)
    ///
    /// Derivations represent build plans in Nix. They specify how to build a package
    /// including the builder command, arguments, environment variables, and dependencies.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    /// // A derivation would be created via builtins.derivation
    /// ```
    #[serde(skip)]
    Derivation(Arc<Derivation>),
}

impl NixValue {
    // Note: force(), get_attr(), and deep_force() methods are implemented in eval/evaluator.rs
    // to avoid circular dependencies. They are re-exported here via impl blocks.
}
