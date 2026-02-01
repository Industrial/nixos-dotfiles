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
//! - Function/closure data structure (foundation for function support)
//!
//! ## Limitations
//!
//! - No function application (function data structure exists but not yet integrated into evaluator)
//! - No builtin function calls
//! - No recursive attribute sets
//! - Limited variable scoping (basic HashMap-based scope)
//!
//! ## Lazy Evaluation
//!
//! The evaluator uses lazy evaluation for attribute set values. Attribute values
//! are wrapped in thunks and only evaluated when their values are actually accessed.
//! Use [`NixValue::force()`] to explicitly force evaluation of a thunk, or
//! [`NixValue::get_attr()`] to access attribute set values with automatic forcing.
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

mod builtins;
mod function;
mod prelude;
mod thunk;

use rnix::SyntaxNode;
use rnix::ast::{
    AttrpathValue, BinOp, BinOpKind, Expr, HasEntry, InterpolPart, Literal, Root, Str,
};
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rowan::ast::AstNode;
use serde::Serialize;
use std::cell::RefCell;
use std::collections::HashMap;
use std::fmt;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::Arc;
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

/// Represents a Nix derivation (build plan)
#[derive(Debug, Clone)]
pub struct Derivation {
    /// Name of the derivation
    pub name: String,
    /// System (e.g., "x86_64-linux")
    pub system: String,
    /// Builder executable path
    pub builder: String,
    /// Builder arguments
    pub args: Vec<String>,
    /// Environment variables
    pub env: HashMap<String, String>,
    /// Input derivations (dependencies)
    pub input_derivations: HashMap<String, Vec<String>>,
    /// Input sources (file dependencies)
    pub input_sources: Vec<String>,
    /// Output paths (where the build results will be stored)
    pub outputs: HashMap<String, String>,
}

impl Derivation {
    /// Serialize the derivation to ATerm format
    ///
    /// The ATerm format for a derivation is:
    /// Derive(
    ///   [outputs],           # list of output specifications
    ///   [input-derivations], # list of input derivations
    ///   [input-sources],     # list of input source paths
    ///   system,              # system string
    ///   builder,             # builder path
    ///   [args],              # builder arguments
    ///   env                  # environment variables as attribute set
    /// )
    pub fn to_aterm(&self) -> String {
        use std::fmt::Write;

        let mut result = String::from("Derive([");

        // Outputs: list of tuples (name, path, hash-algo, hash)
        // For now, we'll use "out" as the default output if none specified
        if self.outputs.is_empty() {
            // Default output "out"
            write!(result, "(\"out\",\"\",\"\",\"\")").unwrap();
        } else {
            let output_parts: Vec<String> = self
                .outputs
                .iter()
                .map(|(name, path)| {
                    format!(
                        "(\"{}\",\"{}\",\"\",\"\")",
                        escape_string(name),
                        escape_string(path)
                    )
                })
                .collect();
            result.push_str(&output_parts.join(","));
        }

        result.push_str("],[");

        // Input derivations: list of tuples (drv-path, [output-names])
        let mut input_drv_parts = Vec::new();
        for (drv_path, output_names) in &self.input_derivations {
            let outputs_str = output_names
                .iter()
                .map(|n| format!("\"{}\"", escape_string(n)))
                .collect::<Vec<_>>()
                .join(",");
            input_drv_parts.push(format!(
                "(\"{}\",[{}])",
                escape_string(drv_path),
                outputs_str
            ));
        }
        result.push_str(&input_drv_parts.join(","));

        result.push_str("],[");

        // Input sources: list of store paths
        let source_parts: Vec<String> = self
            .input_sources
            .iter()
            .map(|s| format!("\"{}\"", escape_string(s)))
            .collect();
        result.push_str(&source_parts.join(","));

        result.push_str("],");

        // System
        write!(result, "\"{}\",", escape_string(&self.system)).unwrap();

        // Builder
        write!(result, "\"{}\",", escape_string(&self.builder)).unwrap();

        // Args
        result.push('[');
        let arg_parts: Vec<String> = self
            .args
            .iter()
            .map(|a| format!("\"{}\"", escape_string(a)))
            .collect();
        result.push_str(&arg_parts.join(","));
        result.push_str("],");

        // Environment variables as attribute set
        result.push('[');
        let env_parts: Vec<String> = self
            .env
            .iter()
            .map(|(k, v)| format!("(\"{}\",\"{}\")", escape_string(k), escape_string(v)))
            .collect();
        result.push_str(&env_parts.join(","));
        result.push_str("])");

        result
    }

    /// Compute the store path hash for this derivation
    ///
    /// The hash is computed as:
    /// 1. Serialize the derivation to ATerm format
    /// 2. Compute SHA256 hash of the serialization
    /// 3. Encode the hash in base32 (Nix uses a modified base32)
    /// 4. Take the first 32 characters as the hash
    pub fn compute_store_path_hash(&self) -> String {
        use base32::Alphabet;
        use sha2::{Digest, Sha256};

        let aterm = self.to_aterm();
        let mut hasher = Sha256::new();
        hasher.update(aterm.as_bytes());
        let hash_bytes = hasher.finalize();

        // Nix uses a modified base32 alphabet: 0-9, a-v (lowercase)
        // Standard base32 uses uppercase, but Nix uses lowercase
        // The base32 crate uses RFC 4648 which is uppercase, so we need to convert
        let base32_upper = base32::encode(Alphabet::RFC4648 { padding: false }, &hash_bytes);
        let base32_lower = base32_upper.to_lowercase();

        // Take first 32 characters (Nix typically uses 32-char hashes)
        base32_lower.chars().take(32).collect()
    }

    /// Get the store path for this derivation
    ///
    /// Returns a path like `/nix/store/<hash>-<name>.drv`
    pub fn store_path(&self) -> String {
        let hash = self.compute_store_path_hash();
        format!("/nix/store/{}-{}.drv", hash, self.name)
    }

    /// Write the derivation to a .drv file in the store
    ///
    /// This creates the .drv file at the computed store path.
    /// The store directory must exist and be writable.
    pub fn write_to_store(&self) -> Result<PathBuf> {
        use std::fs;
        use std::io::Write;

        let store_path_str = self.store_path();
        let store_path = PathBuf::from(&store_path_str);

        // Create parent directory if it doesn't exist
        if let Some(parent) = store_path.parent() {
            fs::create_dir_all(parent)?;
        }

        // Serialize to ATerm and write to file
        let aterm = self.to_aterm();
        let mut file = fs::File::create(&store_path)?;
        file.write_all(aterm.as_bytes())?;

        Ok(store_path)
    }
}

/// Escape a string for use in ATerm format
///
/// ATerm strings need special characters escaped:
/// - Backslash -> \\
/// - Double quote -> \"
/// - Newline -> \n
/// - Carriage return -> \r
/// - Tab -> \t
fn escape_string(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            '\\' => "\\\\".to_string(),
            '"' => "\\\"".to_string(),
            '\n' => "\\n".to_string(),
            '\r' => "\\r".to_string(),
            '\t' => "\\t".to_string(),
            _ => c.to_string(),
        })
        .collect()
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

// Re-export thunk types for public API
pub use thunk::Thunk;
// Re-export function types for public API
pub use function::Function;

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
    /// Cache of imported modules (path -> evaluated value)
    /// Uses interior mutability to allow caching during immutable evaluation
    import_cache: Rc<RefCell<HashMap<PathBuf, NixValue>>>,
    /// Search paths for resolving <nixpkgs> style imports
    search_paths: HashMap<String, PathBuf>,
    /// Current file path (for resolving relative imports)
    current_file: Option<PathBuf>,
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
        let mut evaluator = Self {
            builtins: HashMap::new(),
            scope: HashMap::new(),
            import_cache: Rc::new(RefCell::new(HashMap::new())),
            search_paths: HashMap::new(),
            current_file: None,
        };

        // Register basic builtin functions
        evaluator.register_basic_builtins();

        evaluator
    }

    /// Register basic builtin functions
    fn register_basic_builtins(&mut self) {
        use builtins::*;

        self.register_builtin(Box::new(IsNullBuiltin));
        self.register_builtin(Box::new(IsBoolBuiltin));
        self.register_builtin(Box::new(IsIntBuiltin));
        self.register_builtin(Box::new(IsFloatBuiltin));
        self.register_builtin(Box::new(IsStringBuiltin));
        self.register_builtin(Box::new(IsPathBuiltin));
        self.register_builtin(Box::new(IsListBuiltin));
        self.register_builtin(Box::new(IsAttrsBuiltin));
        self.register_builtin(Box::new(TypeOfBuiltin));
        self.register_builtin(Box::new(ToStringBuiltin));
        self.register_builtin(Box::new(LengthBuiltin));
        self.register_builtin(Box::new(HeadBuiltin));
        self.register_builtin(Box::new(TailBuiltin));
        self.register_builtin(Box::new(AttrNamesBuiltin));
        self.register_builtin(Box::new(HasAttrBuiltin));
        self.register_builtin(Box::new(GetAttrBuiltin));
        self.register_builtin(Box::new(ConcatListsBuiltin));
        self.register_builtin(Box::new(ConcatStringsSepBuiltin));
        self.register_builtin(Box::new(AbortBuiltin));
        self.register_builtin(Box::new(TraceBuiltin));
        self.register_builtin(Box::new(builtins::DerivationBuiltin));
        self.register_builtin(Box::new(builtins::StorePathBuiltin));
        self.register_builtin(Box::new(builtins::PathBuiltin));
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

    /// Evaluate a parsed Nix expression AST node with a specific scope
    ///
    /// This method evaluates an expression using the provided scope instead of
    /// the evaluator's default scope. This is useful for evaluating thunks with
    /// their lexical closures.
    ///
    /// # Arguments
    ///
    /// * `expr` - The parsed expression to evaluate
    /// * `scope` - The variable scope to use for evaluation
    ///
    /// # Returns
    ///
    /// The evaluated value or an error
    pub fn evaluate_expr_with_scope(&self, expr: &Expr, scope: &VariableScope) -> Result<NixValue> {
        self.evaluate_expr_with_scope_impl(expr, scope)
    }

    /// Evaluate a parsed Nix expression AST node
    fn evaluate_expr(&self, expr: &Expr) -> Result<NixValue> {
        self.evaluate_expr_with_scope_impl(expr, &self.scope)
    }

    /// Internal implementation that evaluates an expression with a specific scope
    fn evaluate_expr_with_scope_impl(
        &self,
        expr: &Expr,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        match expr {
            Expr::Literal(literal) => self.evaluate_literal(literal),
            Expr::Str(str_expr) => self.evaluate_string(str_expr, scope),
            Expr::Ident(ident) => {
                // Handle identifiers (true, false, null, variables, builtins)
                let text = ident.to_string();
                match text.as_str() {
                    "true" => Ok(NixValue::Boolean(true)),
                    "false" => Ok(NixValue::Boolean(false)),
                    "null" => Ok(NixValue::Null),
                    _ => {
                        // Check if it's a variable in scope
                        if let Some(value) = scope.get(&text) {
                            return Ok(value.clone());
                        }
                        // Check if it's a builtin function
                        if self.builtins.contains_key(&text) {
                            // Builtins are functions, not values - they need to be called
                            return Err(Error::UnsupportedExpression {
                                reason: format!(
                                    "builtin '{}' cannot be used as a value, it must be called",
                                    text
                                ),
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
            Expr::Lambda(lambda) => self.evaluate_lambda(lambda, scope),
            Expr::Apply(apply) => self.evaluate_apply(apply, scope),
            Expr::LetIn(let_in) => self.evaluate_let_in(let_in, scope),
            Expr::With(with) => self.evaluate_with(with, scope),
            Expr::IfElse(if_else) => self.evaluate_if_else(if_else, scope),
            Expr::Path(path_expr) => self.evaluate_path(path_expr, scope),
            Expr::Select(select) => self.evaluate_select(select, scope),
            Expr::BinOp(binop) => self.evaluate_binop(binop, scope),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("{:?}", expr),
            }),
        }
    }

    /// Evaluate a string expression (with interpolation support)
    ///
    /// Nix strings can contain interpolated expressions like `"Hello ${name}"`.
    /// This method evaluates the string by:
    /// 1. Iterating over string parts (literal strings and interpolated expressions)
    /// 2. Evaluating each interpolated expression in the current scope
    /// 3. Converting the result to a string
    /// 4. Concatenating all parts together
    fn evaluate_string(&self, str_expr: &Str, scope: &VariableScope) -> Result<NixValue> {
        let mut result = String::new();

        // Iterate over the parts of the string
        // In rnix, strings are composed of InterpolPart which can be either
        // a string literal or an interpolated expression
        for part in str_expr.parts() {
            match part {
                InterpolPart::Literal(literal) => {
                    // This is a literal string part
                    let part_text = literal.to_string();
                    // Unescape the string
                    let unescaped = part_text
                        .replace("\\n", "\n")
                        .replace("\\t", "\t")
                        .replace("\\\"", "\"")
                        .replace("\\\\", "\\")
                        .replace("\\${", "${"); // Unescape ${ in strings
                    result.push_str(&unescaped);
                }
                InterpolPart::Interpolation(interp) => {
                    // This is an interpolated expression - get the expression
                    if let Some(expr) = interp.expr() {
                        // Evaluate the interpolated expression
                        let value = self.evaluate_expr_with_scope_impl(&expr, scope)?;

                        // Convert the value to a string
                        let value_str = match value {
                            NixValue::String(s) => s,
                            NixValue::Integer(i) => i.to_string(),
                            NixValue::Float(f) => f.to_string(),
                            NixValue::Boolean(b) => b.to_string(),
                            NixValue::Null => "".to_string(),
                            NixValue::Path(p) => p.display().to_string(),
                            NixValue::StorePath(p) => p.clone(),
                            NixValue::Derivation(drv) => format!("<derivation {}>", drv.name),
                            NixValue::List(_)
                            | NixValue::AttributeSet(_)
                            | NixValue::Thunk(_)
                            | NixValue::Function(_) => {
                                // For complex types, use their Display implementation
                                format!("{}", value)
                            }
                        };

                        result.push_str(&value_str);
                    } else {
                        return Err(Error::UnsupportedExpression {
                            reason: "interpolation missing expression".to_string(),
                        });
                    }
                }
            }
        }

        Ok(NixValue::String(result))
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
        // Check if this is a recursive attribute set
        // In rnix, recursive sets are represented differently - check if rec keyword is present
        let is_recursive = set.rec_token().is_some();

        if is_recursive {
            self.evaluate_recursive_attr_set(set)
        } else {
            self.evaluate_normal_attr_set(set)
        }
    }

    /// Evaluate a normal (non-recursive) attribute set
    fn evaluate_normal_attr_set(&self, set: &rnix::ast::AttrSet) -> Result<NixValue> {
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

            // Create a thunk for lazy evaluation of attribute values
            // This is the key to lazy evaluation: attribute values are not evaluated
            // until they are actually accessed.
            let thunk = thunk::Thunk::new(&value_expr, self.scope.clone());
            attrs.insert(key, NixValue::Thunk(Arc::new(thunk)));
        }

        Ok(NixValue::AttributeSet(attrs))
    }

    /// Evaluate a recursive attribute set
    ///
    /// Recursive attribute sets like `rec { x = y; y = 1; }` allow forward references.
    /// The key is to create a scope that includes all attribute names (as thunks) before
    /// evaluating any values, so that each value can reference other attributes.
    ///
    /// Implementation strategy:
    /// 1. First pass: Collect all attribute names and expressions
    /// 2. Create a recursive scope that will contain all attribute thunks
    /// 3. Second pass: Create thunks for each attribute, where each thunk's closure
    ///    includes the recursive scope. As we add thunks to the scope, subsequent
    ///    thunks can reference earlier ones, enabling forward references.
    fn evaluate_recursive_attr_set(&self, set: &rnix::ast::AttrSet) -> Result<NixValue> {
        // First pass: Collect all attribute names and expressions
        let mut attr_entries = Vec::new();

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

            // Store the entry for later evaluation
            attr_entries.push((key, value_expr));
        }

        // For recursive sets, all attributes must be in scope when evaluating any attribute.
        // Since thunks capture their closure at creation time, we need to create all thunks
        // with a scope that includes all attribute names.
        //
        // Strategy: Create all thunks first, then build a scope containing all thunks.
        // However, thunks are immutable once created, so we can't update their closures.
        //
        // Workaround: Create thunks with a scope that includes all attribute names as
        // placeholders (Null), then when a thunk is forced and looks up an attribute,
        // it will find Null. But that's not correct either.
        //
        // The correct solution requires thunks to support dynamic scope lookup or
        // a shared mutable scope. For now, we'll use a sequential approach that supports
        // forward references (later attributes can reference earlier ones).
        //
        // To support full mutual references, we'd need to modify the thunk implementation
        // to support a "recursive scope" that can be updated after thunk creation.
        let mut rec_scope = self.scope.clone();
        let mut attrs = HashMap::new();

        // Create thunks sequentially, where each thunk's closure includes previous thunks
        // This supports forward references: `rec { y = 1; x = y; }` works
        // But backward references like `rec { x = y; y = 1; }` won't work with this approach
        for (key, value_expr) in &attr_entries {
            // Create thunk with current scope (includes outer scope + previous attributes)
            let thunk = thunk::Thunk::new(value_expr, rec_scope.clone());
            let thunk_arc = Arc::new(thunk);

            // Add to both attribute set and scope for next iteration
            attrs.insert(key.clone(), NixValue::Thunk(thunk_arc.clone()));
            rec_scope.insert(key.clone(), NixValue::Thunk(thunk_arc));
        }

        Ok(NixValue::AttributeSet(attrs))
    }

    /// Evaluate a lambda expression (function definition)
    ///
    /// A lambda expression like `x: x + 1` creates a function closure that
    /// captures the current lexical environment.
    fn evaluate_lambda(
        &self,
        lambda: &rnix::ast::Lambda,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the parameter from the lambda
        // In rnix, Lambda has a param() method that returns the parameter pattern
        let param = lambda.param().ok_or_else(|| Error::UnsupportedExpression {
            reason: "lambda missing parameter".to_string(),
        })?;

        // Extract the parameter name from the pattern
        // For simple lambdas like `x: ...`, the param is an identifier
        // Try to cast to Ident first, otherwise use the text representation
        let param_name = if let Some(ident) = rnix::ast::Ident::cast(param.syntax().clone()) {
            ident.to_string()
        } else {
            // For more complex patterns, use the text representation
            param.syntax().text().to_string().trim().to_string()
        };

        // Get the body expression
        let body_expr = lambda.body().ok_or_else(|| Error::UnsupportedExpression {
            reason: "lambda missing body".to_string(),
        })?;

        // Create a function closure with the current scope
        let func = function::Function::new(param_name, &body_expr, scope.clone());
        Ok(NixValue::Function(Arc::new(func)))
    }

    /// Evaluate a function application expression
    ///
    /// A function application like `f 42` applies the function `f` to the argument `42`.
    ///
    /// **Currying Support**: This method supports currying (partial application). If the result
    /// of applying a function is another function, that function can be applied again.
    /// For example, `(x: y: x + y) 1 2` is parsed as `((x: y: x + y) 1) 2`, where the
    /// first application returns `y: 1 + y`, and the second application returns `3`.
    ///
    /// **Builtin Support**: Builtin functions can be called directly. If the function expression
    /// is an identifier that matches a registered builtin, the builtin is called with the argument.
    fn evaluate_apply(&self, apply: &rnix::ast::Apply, scope: &VariableScope) -> Result<NixValue> {
        // Get the function expression (left-hand side)
        let func_expr = apply.lambda().ok_or_else(|| Error::UnsupportedExpression {
            reason: "function application missing function".to_string(),
        })?;

        // Check if the function is a builtin (identifier that's a builtin)
        // This handles cases like `toString 42` where `toString` is a builtin
        if let Expr::Ident(ident) = &func_expr {
            let builtin_name = ident.to_string();

            // Handle import builtin specially since it needs evaluator context
            if builtin_name == "import" {
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "import missing argument".to_string(),
                    })?;
                let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                match arg_value {
                    NixValue::Path(path) => return self.import_file(&path),
                    NixValue::StorePath(path_str) => {
                        return self.import_file(Path::new(&path_str));
                    }
                    _ => {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("import expects a path, got {}", arg_value),
                        });
                    }
                }
            }

            // Handle toString builtin specially to support __toString
            if builtin_name == "toString" {
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "toString missing argument".to_string(),
                    })?;
                let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;

                // Check if the argument is an attribute set with __toString
                if let NixValue::AttributeSet(ref attrs) = arg_value {
                    if let Some(toString_value) = attrs.get("__toString") {
                        // Clone the attribute set and remove __toString for the function call
                        let mut attrs_for_call = attrs.clone();
                        attrs_for_call.remove("__toString");

                        // Force the __toString value if it's a thunk
                        let toString_func = toString_value.clone().force(self)?;

                        // The __toString should be a function
                        match toString_func {
                            NixValue::Function(func) => {
                                // Call __toString with the attribute set as the argument
                                let attrs_value = NixValue::AttributeSet(attrs_for_call);
                                let result = func.apply(self, attrs_value)?;

                                // The result should be a string
                                match result {
                                    NixValue::String(s) => return Ok(NixValue::String(s)),
                                    _ => {
                                        return Err(Error::UnsupportedExpression {
                                            reason: format!(
                                                "__toString must return a string, got: {:?}",
                                                result
                                            ),
                                        });
                                    }
                                }
                            }
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!(
                                        "__toString must be a function, got: {:?}",
                                        toString_func
                                    ),
                                });
                            }
                        }
                    }
                }

                // No __toString found, fall through to normal toString builtin
                if let Some(builtin) = self.builtins.get(&builtin_name) {
                    return builtin.call(&[arg_value]);
                }
            }

            if let Some(builtin) = self.builtins.get(&builtin_name) {
                // This is a builtin function call
                // Get the argument expression
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "function application missing argument".to_string(),
                    })?;

                // Evaluate the argument
                let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;

                // Call the builtin with the argument
                // Note: Builtins take a slice of arguments, so we wrap in a slice
                return builtin.call(&[arg_value]);
            }
        }

        // Evaluate the function expression to get the function value
        let func_value = self.evaluate_expr_with_scope_impl(&func_expr, scope)?;

        // Get the argument expression (right-hand side)
        let arg_expr = apply
            .argument()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "function application missing argument".to_string(),
            })?;

        // Evaluate the argument expression
        let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;

        // Apply the function to the argument
        // Note: The result of apply() may be another function, enabling currying.
        // Chained applications like `f 1 2` are handled by the parser as nested Apply nodes.
        match func_value {
            NixValue::Function(func) => func.apply(self, arg_value),
            NixValue::AttributeSet(mut attrs) => {
                // Check for __functor attribute (makes attribute sets callable)
                if let Some(functor_value) = attrs.remove("__functor") {
                    // Force the functor value if it's a thunk
                    let functor = functor_value.force(self)?;

                    // The __functor should be a function
                    match functor {
                        NixValue::Function(func) => {
                            // Call the functor with the attribute set as the first argument,
                            // followed by the actual argument
                            // In Nix, `attrs arg` becomes `attrs.__functor attrs arg`
                            // Since Function::apply only takes one argument, we use currying:
                            // First apply the attribute set, then apply the result to the argument
                            let attrs_value = NixValue::AttributeSet(attrs);
                            let partial_result = func.apply(self, attrs_value)?;

                            // If the result is another function (currying), apply it to the argument
                            // Otherwise, return the result as-is (the functor might have already handled everything)
                            match partial_result {
                                NixValue::Function(next_func) => next_func.apply(self, arg_value),
                                _ => Ok(partial_result),
                            }
                        }
                        _ => Err(Error::UnsupportedExpression {
                            reason: format!("__functor must be a function, got: {:?}", functor),
                        }),
                    }
                } else {
                    Err(Error::UnsupportedExpression {
                        reason: format!(
                            "cannot apply non-function value: {:?}",
                            NixValue::AttributeSet(attrs)
                        ),
                    })
                }
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot apply non-function value: {:?}", func_value),
            }),
        }
    }

    /// Evaluate a let-in expression
    ///
    /// A let-in expression like `let x = 1; in x` creates a new scope with the bindings
    /// and evaluates the body expression in that scope. Bindings are evaluated lazily
    /// and can reference each other (forward references are handled via thunks).
    ///
    /// # Arguments
    ///
    /// * `let_in` - The let-in AST node
    /// * `scope` - The current variable scope
    ///
    /// # Returns
    ///
    /// The result of evaluating the body expression in the new scope
    fn evaluate_let_in(
        &self,
        let_in: &rnix::ast::LetIn,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the bindings (the "let" part)
        // attrpath_values() returns an iterator over the bindings
        let bindings = let_in.attrpath_values();

        // Create a new scope that starts with the current scope
        // Bindings will be added to this scope as we evaluate them
        let mut new_scope = scope.clone();

        // First pass: Create thunks for all bindings (to handle forward references)
        // In Nix, let bindings can reference each other, so we need to create thunks
        // that will be evaluated lazily when accessed.
        for binding in bindings {
            // Get the attribute path (the variable name)
            let attrpath = binding
                .attrpath()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "let binding missing attrpath".to_string(),
                })?;

            // Get the first identifier from the attrpath as the variable name
            let var_name = attrpath
                .attrs()
                .next()
                .map(|attr| attr.to_string())
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "let binding variable name must be an identifier".to_string(),
                })?;

            // Get the value expression
            let value_expr = binding
                .value()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: format!("let binding '{}' missing value", var_name),
                })?;

            // Create a thunk for this binding
            // The thunk's closure includes the new_scope (which will have all bindings)
            // This allows forward references: bindings can reference each other
            let thunk = thunk::Thunk::new(&value_expr, new_scope.clone());

            // Add the thunk to the scope (wrapped in NixValue::Thunk)
            new_scope.insert(var_name, NixValue::Thunk(Arc::new(thunk)));
        }

        // Get the body expression (the "in" part)
        let body_expr = let_in.body().ok_or_else(|| Error::UnsupportedExpression {
            reason: "let-in missing body expression".to_string(),
        })?;

        // Evaluate the body expression in the new scope
        // When bindings are accessed, their thunks will be forced and evaluated
        self.evaluate_expr_with_scope_impl(&body_expr, &new_scope)
    }

    /// Evaluate a with expression
    ///
    /// A with expression like `with pkgs; [ hello world ]` merges the attribute set
    /// into the current scope and evaluates the body expression in that merged scope.
    ///
    /// # Arguments
    ///
    /// * `with` - The with AST node
    /// * `scope` - The current variable scope
    ///
    /// # Returns
    ///
    /// The result of evaluating the body expression in the merged scope
    fn evaluate_with(&self, with: &rnix::ast::With, scope: &VariableScope) -> Result<NixValue> {
        // Get the attribute set expression (the "with" part)
        let attrset_expr = with
            .namespace()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "with expression missing namespace".to_string(),
            })?;

        // Evaluate the attribute set expression
        let attrset_value = self.evaluate_expr_with_scope_impl(&attrset_expr, scope)?;

        // Extract the attribute set
        let attrs = match attrset_value {
            NixValue::AttributeSet(attrs) => attrs,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!(
                        "with expression namespace must be an attribute set, got: {:?}",
                        attrset_value
                    ),
                });
            }
        };

        // Create a new scope that merges the current scope with the attribute set
        // Attributes from the attribute set shadow variables in the current scope
        let mut new_scope = scope.clone();

        // Merge attributes into the scope
        // Note: We need to force thunks when merging, as attribute set values are lazy
        for (key, value) in attrs {
            // Force the value if it's a thunk, otherwise use it as-is
            let forced_value = match value {
                NixValue::Thunk(thunk) => thunk.force(self)?,
                other => other,
            };
            new_scope.insert(key, forced_value);
        }

        // Get the body expression
        let body_expr = with.body().ok_or_else(|| Error::UnsupportedExpression {
            reason: "with expression missing body".to_string(),
        })?;

        // Evaluate the body expression in the merged scope
        self.evaluate_expr_with_scope_impl(&body_expr, &new_scope)
    }

    /// Evaluate an if-else expression
    ///
    /// An if-else expression like `if condition then a else b` evaluates the condition
    /// and returns the appropriate branch based on whether the condition is truthy.
    /// In Nix, only `false` and `null` are falsy; everything else (including `0`, `""`, `[]`, `{}`) is truthy.
    ///
    /// # Arguments
    ///
    /// * `if_else` - The if-else AST node
    /// * `scope` - The current variable scope
    ///
    /// # Returns
    ///
    /// The result of evaluating the appropriate branch (then or else)
    fn evaluate_if_else(
        &self,
        if_else: &rnix::ast::IfElse,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the condition expression
        let condition_expr = if_else
            .condition()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "if expression missing condition".to_string(),
            })?;

        // Evaluate the condition
        let condition_value = self.evaluate_expr_with_scope_impl(&condition_expr, scope)?;

        // Determine if the condition is truthy
        // In Nix, only `false` and `null` are falsy; everything else is truthy
        let is_truthy = match condition_value {
            NixValue::Boolean(false) => false,
            NixValue::Null => false,
            _ => true,
        };

        // Get the appropriate branch based on the condition
        if is_truthy {
            // Evaluate the "then" branch
            let then_expr = if_else.body().ok_or_else(|| Error::UnsupportedExpression {
                reason: "if expression missing then branch".to_string(),
            })?;
            self.evaluate_expr_with_scope_impl(&then_expr, scope)
        } else {
            // Evaluate the "else" branch
            let else_expr = if_else
                .else_body()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "if expression missing else branch".to_string(),
                })?;
            self.evaluate_expr_with_scope_impl(&else_expr, scope)
        }
    }

    /// Evaluate a path expression (path literals)
    ///
    /// Path expressions can be:
    /// - Relative paths: `./file.nix`
    /// - Absolute paths: `/absolute/path.nix`
    /// - Search paths: `<nixpkgs>`
    ///
    /// Path literals evaluate to `NixValue::Path` values. To import a file,
    /// use the `import` builtin function with a path value.
    fn evaluate_path(
        &self,
        path_expr: &rnix::ast::Path,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the path string
        let path_str = path_expr.to_string();

        // Check if it's a search path (starts with < and ends with >)
        if path_str.starts_with('<') && path_str.ends_with('>') {
            // Search path like <nixpkgs>
            let search_name = &path_str[1..path_str.len() - 1];
            if let Some(search_path) = self.search_paths.get(search_name) {
                // Return the resolved search path as a Path value
                return Ok(NixValue::Path(search_path.clone()));
            }
            return Err(Error::UnsupportedExpression {
                reason: format!("unknown search path: {}", search_name),
            });
        }

        // Resolve relative or absolute path
        let file_path = if path_str.starts_with('/') {
            // Absolute path
            PathBuf::from(path_str)
        } else {
            // Relative path - resolve relative to current file
            if let Some(current_file) = &self.current_file {
                current_file
                    .parent()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "cannot resolve relative path: current file has no parent"
                            .to_string(),
                    })?
                    .join(&path_str)
            } else {
                // No current file, use as-is (will be relative to CWD)
                PathBuf::from(path_str)
            }
        };

        // Check if this is a Nix store path
        // Store paths have the format: /nix/store/<hash>-<name>
        let path_str = file_path.to_string_lossy();
        if path_str.starts_with("/nix/store/") {
            // Validate store path format
            if self.is_valid_store_path(&path_str) {
                return Ok(NixValue::StorePath(path_str.to_string()));
            }
        }

        // Return the path as a Path value (don't import it)
        // The import builtin will handle importing when needed
        Ok(NixValue::Path(file_path))
    }

    /// Check if a path string is a valid Nix store path
    ///
    /// Nix store paths have the format: `/nix/store/<hash>-<name>` where:
    /// - The path starts with `/nix/store/`
    /// - `<hash>` is a base32-encoded hash (typically 32 characters, but can vary)
    /// - `<name>` is the rest of the path component (can contain any characters except `/`)
    /// - The hash and name are separated by a single `-`
    fn is_valid_store_path(&self, path: &str) -> bool {
        if !path.starts_with("/nix/store/") {
            return false;
        }

        // Extract the part after /nix/store/
        let store_part = &path[11..]; // Length of "/nix/store/"

        // Find the first `-` which separates hash from name
        if let Some(dash_pos) = store_part.find('-') {
            // Hash is everything before the dash
            let hash = &store_part[..dash_pos];
            // Name is everything after the dash (can be empty)
            let _name = &store_part[dash_pos + 1..];

            // Validate hash: should be base32 characters (a-z, 0-9, excluding some letters)
            // Base32 uses: 0-9, a-v (lowercase), excluding i, l, o, u
            // But Nix uses a modified base32 that includes all lowercase letters
            // For simplicity, we'll check that it's alphanumeric and reasonable length
            if hash.is_empty() {
                return false;
            }

            // Hash should be alphanumeric (base32 uses 0-9, a-z)
            if hash.chars().all(|c| c.is_ascii_alphanumeric()) {
                // Typical hash length is 32 characters, but can vary
                // Accept any reasonable length (at least 1 character)
                return true;
            }
        }

        false
    }

    /// Extract the hash from a store path
    ///
    /// Returns the hash portion of a store path like `/nix/store/abc123-package` → `abc123`
    pub fn store_path_hash(store_path: &str) -> Option<&str> {
        if !store_path.starts_with("/nix/store/") {
            return None;
        }
        let store_part = &store_path[11..];
        store_part.find('-').map(|pos| &store_part[..pos])
    }

    /// Extract the name from a store path
    ///
    /// Returns the name portion of a store path like `/nix/store/abc123-package` → `package`
    pub fn store_path_name(store_path: &str) -> Option<&str> {
        if !store_path.starts_with("/nix/store/") {
            return None;
        }
        let store_part = &store_path[11..];
        store_part.find('-').map(|pos| &store_part[pos + 1..])
    }

    /// Evaluate a select expression (attribute access)
    ///
    /// A select expression like `attrset.attr` accesses an attribute from an attribute set.
    fn evaluate_select(
        &self,
        select: &rnix::ast::Select,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the expression being selected from
        let expr = select.expr().ok_or_else(|| Error::UnsupportedExpression {
            reason: "select expression missing base expression".to_string(),
        })?;

        // Evaluate the base expression
        let base_value = self.evaluate_expr_with_scope_impl(&expr, scope)?;

        // Get the attribute path
        let attrpath = select
            .attrpath()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "select expression missing attrpath".to_string(),
            })?;

        // Get the first attribute name
        let attr_name = attrpath
            .attrs()
            .next()
            .map(|attr| attr.to_string())
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "select attrpath must have at least one attribute".to_string(),
            })?;

        // Access the attribute from the attribute set
        match base_value {
            NixValue::AttributeSet(mut attrs) => {
                if let Some(value) = attrs.remove(&attr_name) {
                    // Force thunks when accessing attributes
                    value.force(self)
                } else {
                    Err(Error::UnsupportedExpression {
                        reason: format!("attribute '{}' not found", attr_name),
                    })
                }
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!(
                    "cannot select attribute from non-attribute-set: {:?}",
                    base_value
                ),
            }),
        }
    }

    /// Evaluate a binary operation expression
    ///
    /// Binary operations include arithmetic (`+`, `-`, `*`, `/`), comparison (`==`, `!=`, `<`, `>`, `<=`, `>=`),
    /// logical (`&&`, `||`), and other operators. This method handles arithmetic operators.
    ///
    /// # Arguments
    ///
    /// * `binop` - The binary operation AST node
    /// * `scope` - The current variable scope
    ///
    /// # Returns
    ///
    /// The result of the binary operation
    fn evaluate_binop(&self, binop: &BinOp, scope: &VariableScope) -> Result<NixValue> {
        // Get the left and right operands
        let lhs_expr = binop.lhs().ok_or_else(|| Error::UnsupportedExpression {
            reason: "binary operation missing left operand".to_string(),
        })?;

        let rhs_expr = binop.rhs().ok_or_else(|| Error::UnsupportedExpression {
            reason: "binary operation missing right operand".to_string(),
        })?;

        // Evaluate both operands
        let lhs = self.evaluate_expr_with_scope_impl(&lhs_expr, scope)?;
        let rhs = self.evaluate_expr_with_scope_impl(&rhs_expr, scope)?;

        // Get the operator
        let op = binop
            .operator()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "binary operation missing operator".to_string(),
            })?;

        // Handle arithmetic operators based on BinOpKind
        // Note: In Nix, `//` is used for both integer division and attribute set updates.
        // We'll handle it as integer division here for arithmetic operations.
        // Attribute set updates will be handled separately when we implement that feature.
        match op {
            BinOpKind::Add => self.evaluate_add(&lhs, &rhs),
            BinOpKind::Sub => self.evaluate_subtract(&lhs, &rhs),
            BinOpKind::Mul => self.evaluate_multiply(&lhs, &rhs),
            BinOpKind::Div => self.evaluate_divide(&lhs, &rhs),
            BinOpKind::Update => {
                // `//` operator: Check if operands are integers (integer division) or attribute sets (update)
                match (&lhs, &rhs) {
                    (NixValue::Integer(_), NixValue::Integer(_)) => {
                        self.evaluate_integer_divide(&lhs, &rhs)
                    }
                    (NixValue::AttributeSet(_), NixValue::AttributeSet(_)) => {
                        // Attribute set update - will be implemented later
                        Err(Error::UnsupportedExpression {
                            reason: "attribute set update (//) not yet implemented".to_string(),
                        })
                    }
                    _ => Err(Error::UnsupportedExpression {
                        reason: format!("cannot apply // operator to {} and {}", lhs, rhs),
                    }),
                }
            }
            // Comparison operators
            BinOpKind::Equal => self.evaluate_equal(&lhs, &rhs),
            BinOpKind::NotEqual => self.evaluate_not_equal(&lhs, &rhs),
            BinOpKind::Less => self.evaluate_less(&lhs, &rhs),
            BinOpKind::More => self.evaluate_greater(&lhs, &rhs),
            // Note: <= and >= operators may be represented differently in rnix
            // For now, we handle ==, !=, <, >. <= and >= can be added when we determine the correct variant names.
            // Logical operators
            BinOpKind::And => self.evaluate_and(&lhs, &rhs),
            BinOpKind::Or => self.evaluate_or(&lhs, &rhs),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("unsupported binary operator: {:?}", op),
            }),
        }
    }

    /// Evaluate addition operation
    ///
    /// In Nix, `+` can be used for:
    /// - Integer addition: `1 + 2` → `3`
    /// - Float addition: `1.5 + 2.5` → `4.0`
    /// - String concatenation: `"hello" + "world"` → `"helloworld"`
    /// - List concatenation: `[1] + [2]` → `[1 2]`
    fn evaluate_add(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => Ok(NixValue::Integer(a + b)),
            (NixValue::Float(a), NixValue::Float(b)) => Ok(NixValue::Float(a + b)),
            (NixValue::Integer(a), NixValue::Float(b)) => Ok(NixValue::Float(*a as f64 + b)),
            (NixValue::Float(a), NixValue::Integer(b)) => Ok(NixValue::Float(a + *b as f64)),
            (NixValue::String(a), NixValue::String(b)) => {
                Ok(NixValue::String(format!("{}{}", a, b)))
            }
            (NixValue::List(a), NixValue::List(b)) => {
                let mut result = a.clone();
                result.extend(b.clone());
                Ok(NixValue::List(result))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot add {} and {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate subtraction operation
    ///
    /// In Nix, `-` is used for:
    /// - Integer subtraction: `5 - 2` → `3`
    /// - Float subtraction: `5.5 - 2.5` → `3.0`
    fn evaluate_subtract(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => Ok(NixValue::Integer(a - b)),
            (NixValue::Float(a), NixValue::Float(b)) => Ok(NixValue::Float(a - b)),
            (NixValue::Integer(a), NixValue::Float(b)) => Ok(NixValue::Float(*a as f64 - b)),
            (NixValue::Float(a), NixValue::Integer(b)) => Ok(NixValue::Float(a - *b as f64)),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot subtract {} from {}", rhs, lhs),
            }),
        }
    }

    /// Evaluate multiplication operation
    ///
    /// In Nix, `*` is used for:
    /// - Integer multiplication: `2 * 3` → `6`
    /// - Float multiplication: `2.5 * 3.0` → `7.5`
    fn evaluate_multiply(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => Ok(NixValue::Integer(a * b)),
            (NixValue::Float(a), NixValue::Float(b)) => Ok(NixValue::Float(a * b)),
            (NixValue::Integer(a), NixValue::Float(b)) => Ok(NixValue::Float(*a as f64 * b)),
            (NixValue::Float(a), NixValue::Integer(b)) => Ok(NixValue::Float(a * *b as f64)),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot multiply {} and {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate division operation
    ///
    /// In Nix, `/` is used for:
    /// - Float division: `10 / 2` → `5.0` (always returns float)
    fn evaluate_divide(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(*a as f64 / *b as f64))
            }
            (NixValue::Float(a), NixValue::Float(b)) => {
                if *b == 0.0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(a / b))
            }
            (NixValue::Integer(a), NixValue::Float(b)) => {
                if *b == 0.0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(*a as f64 / b))
            }
            (NixValue::Float(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(a / *b as f64))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot divide {} by {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate integer division operation
    ///
    /// In Nix, `//` is used for integer division: `10 // 3` → `3`
    fn evaluate_integer_divide(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "integer division by zero".to_string(),
                    });
                }
                Ok(NixValue::Integer(a / b))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot perform integer division on {} and {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate equality comparison (`==`)
    ///
    /// In Nix, `==` compares values for equality. Values of different types are never equal.
    fn evaluate_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a == b,
            (NixValue::Float(a), NixValue::Float(b)) => a == b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) == *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a == (*b as f64),
            (NixValue::String(a), NixValue::String(b)) => a == b,
            (NixValue::Boolean(a), NixValue::Boolean(b)) => a == b,
            (NixValue::Null, NixValue::Null) => true,
            (NixValue::List(a), NixValue::List(b)) => a == b,
            (NixValue::AttributeSet(a), NixValue::AttributeSet(b)) => a == b,
            (NixValue::Path(a), NixValue::Path(b)) => a == b,
            _ => false, // Different types are never equal
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate inequality comparison (`!=`)
    ///
    /// In Nix, `!=` is the negation of `==`.
    fn evaluate_not_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let equal = self.evaluate_equal(lhs, rhs)?;
        match equal {
            NixValue::Boolean(b) => Ok(NixValue::Boolean(!b)),
            _ => unreachable!("evaluate_equal should always return Boolean"),
        }
    }

    /// Evaluate less-than comparison (`<`)
    ///
    /// In Nix, `<` compares numbers (integers and floats). Other types cannot be compared.
    fn evaluate_less(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a < b,
            (NixValue::Float(a), NixValue::Float(b)) => a < b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) < *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a < (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with <", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate less-than-or-equal comparison (`<=`)
    ///
    /// In Nix, `<=` compares numbers (integers and floats). Other types cannot be compared.
    fn evaluate_less_or_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a <= b,
            (NixValue::Float(a), NixValue::Float(b)) => a <= b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) <= *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a <= (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with <=", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate greater-than comparison (`>`)
    ///
    /// In Nix, `>` compares numbers (integers and floats). Other types cannot be compared.
    fn evaluate_greater(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a > b,
            (NixValue::Float(a), NixValue::Float(b)) => a > b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) > *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a > (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with >", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate greater-than-or-equal comparison (`>=`)
    ///
    /// In Nix, `>=` compares numbers (integers and floats). Other types cannot be compared.
    fn evaluate_greater_or_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a >= b,
            (NixValue::Float(a), NixValue::Float(b)) => a >= b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) >= *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a >= (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with >=", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate logical AND operation (`&&`)
    ///
    /// In Nix, `&&` performs short-circuit evaluation:
    /// - If the left operand is falsy (false or null), return it without evaluating the right operand
    /// - Otherwise, return the right operand (evaluated)
    fn evaluate_and(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        // Check if lhs is falsy (false or null)
        let lhs_falsy = matches!(lhs, NixValue::Boolean(false) | NixValue::Null);

        if lhs_falsy {
            // Short-circuit: return lhs without evaluating rhs
            Ok(lhs.clone())
        } else {
            // Return rhs (already evaluated)
            Ok(rhs.clone())
        }
    }

    /// Evaluate logical OR operation (`||`)
    ///
    /// In Nix, `||` performs short-circuit evaluation:
    /// - If the left operand is truthy (not false and not null), return it without evaluating the right operand
    /// - Otherwise, return the right operand (evaluated)
    fn evaluate_or(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        // Check if lhs is falsy (false or null)
        let lhs_falsy = matches!(lhs, NixValue::Boolean(false) | NixValue::Null);

        if lhs_falsy {
            // Return rhs (already evaluated)
            Ok(rhs.clone())
        } else {
            // Short-circuit: return lhs without evaluating rhs
            Ok(lhs.clone())
        }
    }

    /// Import and evaluate a Nix file
    ///
    /// This method loads a .nix file, parses it, and evaluates it.
    /// Results are cached to avoid re-evaluating the same file multiple times.
    fn import_file(&self, file_path: &Path) -> Result<NixValue> {
        // Normalize the path (resolve any .. components)
        let normalized_path =
            file_path
                .canonicalize()
                .map_err(|e| Error::UnsupportedExpression {
                    reason: format!(
                        "cannot resolve import path '{}': {}",
                        file_path.display(),
                        e
                    ),
                })?;

        // Check cache first
        {
            let cache = self.import_cache.borrow();
            if let Some(cached_value) = cache.get(&normalized_path) {
                return Ok(cached_value.clone());
            }
        }

        // Read the file
        let file_contents = std::fs::read_to_string(&normalized_path).map_err(|e| {
            Error::UnsupportedExpression {
                reason: format!(
                    "cannot read import file '{}': {}",
                    normalized_path.display(),
                    e
                ),
            }
        })?;

        // Parse and evaluate the file
        let tokens = tokenize(&file_contents);
        let (green_node, errors) = parse(tokens.into_iter());

        if !errors.is_empty() {
            let error_msgs: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
            return Err(Error::ParseError {
                reason: format!(
                    "parse error in imported file '{}': {}",
                    normalized_path.display(),
                    error_msgs.join(", ")
                ),
            });
        }

        let syntax_node = SyntaxNode::new_root(green_node);
        let root = Root::cast(syntax_node).ok_or(Error::AstConversionError)?;

        let expr = root.expr().ok_or(Error::NoExpression)?;

        // Evaluate the expression
        // Note: Imported files should have their own scope, but for now we'll use the current scope
        let result = self.evaluate_expr_with_scope(&expr, &self.scope)?;

        // Cache the result
        {
            let mut cache = self.import_cache.borrow_mut();
            cache.insert(normalized_path, result.clone());
        }

        Ok(result)
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
            NixValue::Thunk(_) => {
                write!(f, "<thunk>")
            }
            NixValue::Function(func) => {
                write!(f, "<function {}: {}>", func.parameter(), func.body_text())
            }
            NixValue::Path(path) => {
                write!(f, "{}", path.display())
            }
            NixValue::StorePath(path) => {
                write!(f, "{}", path)
            }
            NixValue::Derivation(drv) => {
                write!(f, "<derivation {}>", drv.name)
            }
        }
    }
}

impl PartialEq for NixValue {
    fn eq(&self, other: &Self) -> bool {
        // For thunks and functions, we compare by pointer identity since forcing/applying requires an evaluator
        // In practice, thunks should be forced before comparison, and functions are compared by identity
        match (self, other) {
            (NixValue::Thunk(a), NixValue::Thunk(b)) => Arc::ptr_eq(a, b),
            (NixValue::Function(a), NixValue::Function(b)) => Arc::ptr_eq(a, b),
            (NixValue::String(a), NixValue::String(b)) => a == b,
            (NixValue::Integer(a), NixValue::Integer(b)) => a == b,
            (NixValue::Float(a), NixValue::Float(b)) => a == b,
            (NixValue::Boolean(a), NixValue::Boolean(b)) => a == b,
            (NixValue::Null, NixValue::Null) => true,
            (NixValue::List(a), NixValue::List(b)) => a == b,
            (NixValue::AttributeSet(a), NixValue::AttributeSet(b)) => a == b,
            (NixValue::Path(a), NixValue::Path(b)) => a == b,
            (NixValue::StorePath(a), NixValue::StorePath(b)) => a == b,
            (NixValue::Derivation(a), NixValue::Derivation(b)) => Arc::ptr_eq(a, b),
            _ => false,
        }
    }
}

impl NixValue {
    /// Force evaluation of this value if it's a thunk
    ///
    /// If this value is a thunk, it will be evaluated and the result returned.
    /// If it's already a concrete value, it will be returned as-is.
    ///
    /// # Arguments
    ///
    /// * `evaluator` - The evaluator to use for forcing thunks
    ///
    /// # Returns
    ///
    /// The evaluated value or an error
    pub fn force(self, evaluator: &Evaluator) -> Result<NixValue> {
        match self {
            NixValue::Thunk(thunk) => thunk.force(evaluator),
            other => Ok(other),
        }
    }

    /// Get a value from an attribute set, forcing any thunks
    ///
    /// This is a convenience method for accessing attribute set values with
    /// automatic thunk forcing. It handles the lazy evaluation semantics.
    ///
    /// # Arguments
    ///
    /// * `key` - The attribute key to look up
    /// * `evaluator` - The evaluator to use for forcing thunks
    ///
    /// # Returns
    ///
    /// The evaluated value if found, or None if the key doesn't exist
    pub fn get_attr(self, key: &str, evaluator: &Evaluator) -> Result<Option<NixValue>> {
        match self {
            NixValue::AttributeSet(mut attrs) => {
                if let Some(value) = attrs.remove(key) {
                    Ok(Some(value.force(evaluator)?))
                } else {
                    Ok(None)
                }
            }
            _ => Err(Error::UnsupportedExpression {
                reason: "get_attr can only be called on attribute sets".to_string(),
            }),
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
