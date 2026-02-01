//! # nix-eval
//!
//! A pure Rust library for evaluating Nix expressions.
//!
//! ## Example
//!
//! ```no_run
//! use nix_eval::{Evaluator, NixValue};
//!
//! let evaluator = Evaluator::new();
//! let result = evaluator.evaluate("42").unwrap();
//! assert_eq!(result, NixValue::Integer(42));
//! ```
//!
//! ## Supported Features
//!
//! - Literal values: integers, floats, strings, booleans, null
//! - Lists
//! - Attribute sets
//!
//! ## Limitations
//!
//! - No variable binding or scoping
//! - No builtin functions
//! - No function application
//! - No recursive attribute sets
//!
//! ## Using the Prelude
//!
//! For convenient imports, use the prelude module:
//!
//! ```no_run
//! use nix_eval::prelude::*;
//!
//! let evaluator = Evaluator::new();
//! let result = evaluator.evaluate("42").unwrap();
//! ```

mod prelude;

use rnix::SyntaxNode;
use rnix::ast::{AttrpathValue, Expr, HasEntry, Literal, Root};
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rowan::ast::AstNode;
use serde::Serialize;
use std::collections::HashMap;
use std::fmt;
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
#[derive(Debug, Clone, PartialEq, Serialize)]
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
}

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

/// Represents a variable scope for name resolution
///
/// A scope maps variable names to their values. Scopes can be nested,
/// with inner scopes shadowing outer scopes.
pub type VariableScope = HashMap<String, NixValue>;

/// Evaluates Nix expressions to values
///
/// The `Evaluator` is the main entry point for evaluating Nix expressions.
/// Create a new evaluator with [`Evaluator::new()`], then call [`evaluate()`](Evaluator::evaluate)
/// to evaluate Nix expression strings.
///
/// # Example
///
/// ```no_run
/// use nix_eval::{Evaluator, NixValue};
///
/// // Create a new evaluator
/// let evaluator = Evaluator::new();
///
/// // Evaluate a simple expression
/// let result = evaluator.evaluate("42").unwrap();
/// assert_eq!(result, NixValue::Integer(42));
///
/// // Evaluate a list
/// let list = evaluator.evaluate("[1 2 3]").unwrap();
/// assert!(matches!(list, NixValue::List(_)));
///
/// // Evaluate an attribute set
/// let attrs = evaluator.evaluate("{ foo = \"bar\"; }").unwrap();
/// assert!(matches!(attrs, NixValue::AttributeSet(_)));
/// ```
pub struct Evaluator {
    /// Map of builtin function names to their implementations
    builtins: HashMap<String, Box<dyn Builtin>>,
    /// Current variable scope
    scope: VariableScope,
}

impl Evaluator {
    /// Create a new `Evaluator` instance with no builtins or scope
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::Evaluator;
    ///
    /// let evaluator = Evaluator::new();
    /// ```
    pub fn new() -> Self {
        Self {
            builtins: HashMap::new(),
            scope: HashMap::new(),
        }
    }

    /// Register a builtin function with the evaluator
    ///
    /// Builtin functions can be called from Nix expressions using their name.
    /// If a builtin with the same name already exists, it will be replaced.
    ///
    /// # Arguments
    ///
    /// * `builtin` - A boxed implementation of the `Builtin` trait
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, Builtin, NixValue, Result};
    ///
    /// struct AddBuiltin;
    /// impl Builtin for AddBuiltin {
    ///     fn name(&self) -> &str { "add" }
    ///     fn call(&self, args: &[NixValue]) -> Result<NixValue> {
    ///         // Implementation...
    ///         Ok(NixValue::Integer(0))
    ///     }
    /// }
    ///
    /// let mut evaluator = Evaluator::new();
    /// evaluator.register_builtin(Box::new(AddBuiltin));
    /// ```
    pub fn register_builtin(&mut self, builtin: Box<dyn Builtin>) {
        self.builtins.insert(builtin.name().to_string(), builtin);
    }

    /// Set the variable scope for name resolution
    ///
    /// Variables in the scope can be referenced in Nix expressions.
    /// Setting a new scope replaces any existing scope.
    ///
    /// # Arguments
    ///
    /// * `scope` - A `VariableScope` (HashMap) mapping variable names to values
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    /// use std::collections::HashMap;
    ///
    /// let mut evaluator = Evaluator::new();
    /// let mut scope = HashMap::new();
    /// scope.insert("x".to_string(), NixValue::Integer(42));
    /// scope.insert("y".to_string(), NixValue::String("hello".to_string()));
    /// evaluator.set_scope(scope);
    /// ```
    pub fn set_scope(&mut self, scope: VariableScope) {
        self.scope = scope;
    }

    /// Get a reference to the current variable scope
    ///
    /// # Returns
    ///
    /// A reference to the current `VariableScope`
    pub fn scope(&self) -> &VariableScope {
        &self.scope
    }

    /// Get a mutable reference to the current variable scope
    ///
    /// This allows modifying the scope without replacing it entirely.
    ///
    /// # Returns
    ///
    /// A mutable reference to the current `VariableScope`
    pub fn scope_mut(&mut self) -> &mut VariableScope {
        &mut self.scope
    }

    /// Evaluate a Nix expression string to a [`NixValue`]
    ///
    /// This method parses and evaluates a Nix expression, returning the resulting value
    /// or an error if parsing or evaluation fails.
    ///
    /// # Arguments
    ///
    /// * `expr` - A string containing a valid Nix expression
    ///
    /// # Returns
    ///
    /// * `Ok(NixValue)` - The evaluated value
    /// * `Err(Error)` - An error if parsing or evaluation fails
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, NixValue};
    ///
    /// let evaluator = Evaluator::new();
    ///
    /// // Evaluate an integer
    /// let value = evaluator.evaluate("42").unwrap();
    /// assert_eq!(value, NixValue::Integer(42));
    ///
    /// // Evaluate a string
    /// let value = evaluator.evaluate(r#""hello""#).unwrap();
    /// assert_eq!(value, NixValue::String("hello".to_string()));
    ///
    /// // Evaluate a list
    /// let value = evaluator.evaluate("[1 2 3]").unwrap();
    /// match value {
    ///     NixValue::List(items) => {
    ///         assert_eq!(items.len(), 3);
    ///     }
    ///     _ => panic!("Expected list"),
    /// }
    ///
    /// // Evaluate an attribute set
    /// let value = evaluator.evaluate("{ foo = 1; bar = 2; }").unwrap();
    /// match value {
    ///     NixValue::AttributeSet(attrs) => {
    ///         assert_eq!(attrs.get("foo"), Some(&NixValue::Integer(1)));
    ///     }
    ///     _ => panic!("Expected attribute set"),
    /// }
    /// ```
    pub fn evaluate(&self, expr: &str) -> Result<NixValue> {
        // Tokenize and parse the Nix expression
        let tokens = tokenize(expr);
        let (green_node, errors) = parse(tokens.into_iter());

        // Check for parse errors
        if !errors.is_empty() {
            let error_msgs: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
            return Err(Error::ParseError {
                reason: error_msgs.join(", "),
            });
        }

        // Convert to syntax node and then to AST root
        let syntax_node = SyntaxNode::new_root(green_node);
        let root = Root::cast(syntax_node).ok_or(Error::AstConversionError)?;

        let expr = root.expr().ok_or(Error::NoExpression)?;

        // Evaluate the expression
        self.evaluate_expr(&expr)
    }

    /// Evaluate a parsed Nix expression AST node
    fn evaluate_expr(&self, expr: &Expr) -> Result<NixValue> {
        match expr {
            Expr::Literal(literal) => self.evaluate_literal(literal),
            Expr::Str(str_expr) => {
                // Handle string expressions
                let text = str_expr.to_string();
                // Remove quotes and unescape
                if text.starts_with('"') && text.ends_with('"') {
                    let unescaped = text[1..text.len() - 1]
                        .replace("\\n", "\n")
                        .replace("\\t", "\t")
                        .replace("\\\"", "\"")
                        .replace("\\\\", "\\");
                    Ok(NixValue::String(unescaped))
                } else {
                    Ok(NixValue::String(text))
                }
            }
            Expr::Ident(ident) => {
                // Handle identifiers (true, false, null, variables, builtins)
                let text = ident.to_string();
                match text.as_str() {
                    "true" => Ok(NixValue::Boolean(true)),
                    "false" => Ok(NixValue::Boolean(false)),
                    "null" => Ok(NixValue::Null),
                    _ => {
                        // Check if it's a variable in scope
                        if let Some(value) = self.scope.get(&text) {
                            return Ok(value.clone());
                        }
                        // Check if it's a builtin (for future function call support)
                        if self.builtins.contains_key(&text) {
                            // For now, return an error - function calls not yet implemented
                            return Err(Error::UnsupportedExpression {
                                reason: format!("builtin '{}' cannot be used as a value", text),
                            });
                        }
                        Err(Error::UnsupportedExpression {
                            reason: format!("unknown identifier: {}", text),
                        })
                    }
                }
            }
            Expr::AttrSet(set) => self.evaluate_attr_set(set),
            Expr::List(list) => self.evaluate_list(list),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("{:?}", expr),
            }),
        }
    }

    /// Evaluate a literal value
    fn evaluate_literal(&self, literal: &Literal) -> Result<NixValue> {
        let text = literal.to_string();

        // Remove quotes from string literals
        if text.starts_with('"') && text.ends_with('"') {
            // Basic string unescaping (simplified - doesn't handle all escape sequences)
            let unescaped = text[1..text.len() - 1]
                .replace("\\n", "\n")
                .replace("\\t", "\t")
                .replace("\\\"", "\"")
                .replace("\\\\", "\\");
            return Ok(NixValue::String(unescaped));
        }

        // Check for boolean literals
        if text == "true" {
            return Ok(NixValue::Boolean(true));
        }
        if text == "false" {
            return Ok(NixValue::Boolean(false));
        }
        if text == "null" {
            return Ok(NixValue::Null);
        }

        // Try to parse as integer
        if let Ok(int_val) = text.parse::<i64>() {
            return Ok(NixValue::Integer(int_val));
        }

        // Try to parse as float
        if let Ok(float_val) = text.parse::<f64>() {
            return Ok(NixValue::Float(float_val));
        }

        Err(Error::UnsupportedLiteral { literal: text })
    }

    /// Evaluate a list
    fn evaluate_list(&self, list: &rnix::ast::List) -> Result<NixValue> {
        let mut values = Vec::new();

        for item in list.items() {
            let value = self.evaluate_expr(&item)?;
            values.push(value);
        }

        Ok(NixValue::List(values))
    }

    /// Evaluate an attribute set
    fn evaluate_attr_set(&self, set: &rnix::ast::AttrSet) -> Result<NixValue> {
        let mut attrs = HashMap::new();

        for entry in set.entries() {
            // Entry is an AttrpathValue - cast from the entry's syntax node
            let entry_syntax = entry.syntax();
            let attrpath_value = AttrpathValue::cast(entry_syntax.clone()).ok_or_else(|| {
                Error::UnsupportedExpression {
                    reason: "cannot cast entry to AttrpathValue".to_string(),
                }
            })?;

            // Get the first identifier from the attrpath as the key
            let attrpath =
                attrpath_value
                    .attrpath()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "attribute entry missing attrpath".to_string(),
                    })?;

            // Get the key from the first attribute in the attrpath
            let key = attrpath
                .attrs()
                .next()
                .map(|attr| attr.to_string())
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "attribute key must be an identifier".to_string(),
                })?;

            let value_expr =
                attrpath_value
                    .value()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "attribute entry missing value".to_string(),
                    })?;

            let value = self.evaluate_expr(&value_expr)?;
            attrs.insert(key, value);
        }

        Ok(NixValue::AttributeSet(attrs))
    }
}

impl Default for Evaluator {
    fn default() -> Self {
        Self::new()
    }
}

/// Format a Nix value as a string
impl fmt::Display for NixValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            NixValue::String(s) => write!(f, "\"{}\"", s),
            NixValue::Integer(i) => write!(f, "{}", i),
            NixValue::Float(fl) => write!(f, "{}", fl),
            NixValue::Boolean(b) => write!(f, "{}", b),
            NixValue::Null => write!(f, "null"),
            NixValue::AttributeSet(attrs) => {
                let entries: Vec<String> = attrs
                    .iter()
                    .map(|(k, v)| format!("{} = {};", k, v))
                    .collect();
                write!(f, "{{ {} }}", entries.join(" "))
            }
            NixValue::List(items) => {
                let items_str: Vec<String> = items.iter().map(|v| format!("{}", v)).collect();
                write!(f, "[ {} ]", items_str.join(" "))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_evaluate_integer() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("42").unwrap();
        assert_eq!(result, NixValue::Integer(42));
    }

    #[test]
    fn test_evaluate_string() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate(r#""hello""#).unwrap();
        assert_eq!(result, NixValue::String("hello".to_string()));
    }

    #[test]
    fn test_evaluate_boolean_true() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("true").unwrap();
        assert_eq!(result, NixValue::Boolean(true));
    }

    #[test]
    fn test_evaluate_boolean_false() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("false").unwrap();
        assert_eq!(result, NixValue::Boolean(false));
    }

    #[test]
    fn test_evaluate_null() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("null").unwrap();
        assert_eq!(result, NixValue::Null);
    }

    #[test]
    fn test_evaluate_list() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("[1 2 3]").unwrap();
        assert_eq!(
            result,
            NixValue::List(vec![
                NixValue::Integer(1),
                NixValue::Integer(2),
                NixValue::Integer(3),
            ])
        );
    }

    #[test]
    fn test_evaluate_nested_list() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate(r#"["hello" 42 true]"#).unwrap();
        assert_eq!(
            result,
            NixValue::List(vec![
                NixValue::String("hello".to_string()),
                NixValue::Integer(42),
                NixValue::Boolean(true),
            ])
        );
    }

    #[test]
    fn test_display_integer() {
        let value = NixValue::Integer(42);
        assert_eq!(format!("{}", value), "42");
    }

    #[test]
    fn test_display_string() {
        let value = NixValue::String("hello".to_string());
        assert_eq!(format!("{}", value), r#""hello""#);
    }

    #[test]
    fn test_display_boolean() {
        assert_eq!(format!("{}", NixValue::Boolean(true)), "true");
        assert_eq!(format!("{}", NixValue::Boolean(false)), "false");
    }

    #[test]
    fn test_display_null() {
        assert_eq!(format!("{}", NixValue::Null), "null");
    }

    #[test]
    fn test_display_list() {
        let value = NixValue::List(vec![
            NixValue::Integer(1),
            NixValue::Integer(2),
            NixValue::Integer(3),
        ]);
        assert_eq!(format!("{}", value), "[ 1 2 3 ]");
    }

    #[test]
    fn test_parse_error() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("invalid syntax {");
        assert!(result.is_err());
        match result.unwrap_err() {
            Error::ParseError { .. } => {}
            _ => panic!("Expected ParseError"),
        }
    }

    #[test]
    fn test_evaluate_attribute_set() {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate("{ foo = 1; bar = 2; }").unwrap();
        match result {
            NixValue::AttributeSet(attrs) => {
                assert_eq!(attrs.get("foo"), Some(&NixValue::Integer(1)));
                assert_eq!(attrs.get("bar"), Some(&NixValue::Integer(2)));
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_evaluate_nested_attribute_set() {
        let evaluator = Evaluator::new();
        let result = evaluator
            .evaluate(r#"{ name = "test"; value = 42; }"#)
            .unwrap();
        match result {
            NixValue::AttributeSet(attrs) => {
                assert_eq!(
                    attrs.get("name"),
                    Some(&NixValue::String("test".to_string()))
                );
                assert_eq!(attrs.get("value"), Some(&NixValue::Integer(42)));
            }
            _ => panic!("Expected AttributeSet"),
        }
    }

    #[test]
    fn test_display_attribute_set() {
        let mut attrs = HashMap::new();
        attrs.insert("foo".to_string(), NixValue::Integer(1));
        attrs.insert("bar".to_string(), NixValue::Integer(2));
        let value = NixValue::AttributeSet(attrs);
        let output = format!("{}", value);
        // Output order may vary, so just check it contains both entries
        assert!(output.contains("foo"));
        assert!(output.contains("bar"));
        assert!(output.contains("1"));
        assert!(output.contains("2"));
    }
}
