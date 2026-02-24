//! Evaluator implementation

use crate::builtin::Builtin;
use crate::error::{Error, Result};
use crate::eval::context::{EvaluationContext, VariableScope};
use crate::value::NixValue;
use codespan::{FileId, Files};
use rnix::SyntaxNode;
use rnix::ast::{Expr, Root};
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rowan::ast::AstNode;
use std::cell::RefCell;
use std::collections::HashMap;
use std::path::PathBuf;
use std::rc::Rc;

pub struct Evaluator {
    /// Map of builtin function names to their implementations
    pub(crate) builtins: HashMap<String, Box<dyn Builtin>>,
    /// Current variable scope
    pub(crate) scope: VariableScope,
    /// Cache of imported modules (path -> evaluated value)
    /// Uses interior mutability to allow caching during immutable evaluation
    pub(crate) import_cache: Rc<RefCell<HashMap<PathBuf, NixValue>>>,
    /// Search paths for resolving <nixpkgs> style imports
    pub(crate) search_paths: HashMap<String, PathBuf>,
    /// Source file map for tracking file contents and locations
    /// Uses interior mutability to allow updating during immutable evaluation
    pub(crate) source_map: Rc<RefCell<Files<String>>>,
    /// Mapping from FileId to file path for quick lookup
    /// Uses interior mutability to allow updating during immutable evaluation
    pub(crate) file_id_to_path: Rc<RefCell<HashMap<FileId, PathBuf>>>,
    /// Context stack for tracking evaluation context (file, scope)
    /// The top of the stack represents the current evaluation context
    /// Uses interior mutability to allow updating during immutable evaluation
    context_stack: Rc<RefCell<Vec<EvaluationContext>>>,
}

impl Evaluator {
    pub fn new() -> Self {
        let mut evaluator = Self {
            builtins: HashMap::new(),
            scope: HashMap::new(),
            import_cache: Rc::new(RefCell::new(HashMap::new())),
            search_paths: HashMap::new(),
            source_map: Rc::new(RefCell::new(Files::new())),
            file_id_to_path: Rc::new(RefCell::new(HashMap::new())),
            context_stack: Rc::new(RefCell::new(Vec::new())),
        };

        // Register basic builtin functions
        evaluator.register_basic_builtins();

        // Parse NIX_PATH environment variable to configure search paths
        evaluator.parse_nix_path();

        evaluator
    }

    fn register_basic_builtins(&mut self) {
        use crate::builtins::*;

        self.register_builtin(Box::new(IsNullBuiltin));
        self.register_builtin(Box::new(IsBoolBuiltin));
        self.register_builtin(Box::new(IsIntBuiltin));
        self.register_builtin(Box::new(IsFloatBuiltin));
        self.register_builtin(Box::new(IsStringBuiltin));
        self.register_builtin(Box::new(IsPathBuiltin));
        self.register_builtin(Box::new(IsListBuiltin));
        self.register_builtin(Box::new(IsAttrsBuiltin));
        self.register_builtin(Box::new(IsFunctionBuiltin));
        self.register_builtin(Box::new(TypeOfBuiltin));
        self.register_builtin(Box::new(ToStringBuiltin));
        self.register_builtin(Box::new(LengthBuiltin));
        self.register_builtin(Box::new(HeadBuiltin));
        self.register_builtin(Box::new(TailBuiltin));
        self.register_builtin(Box::new(ElemAtBuiltin));
        self.register_builtin(Box::new(AttrNamesBuiltin));
        self.register_builtin(Box::new(AttrValuesBuiltin));
        self.register_builtin(Box::new(CatAttrsBuiltin));
        self.register_builtin(Box::new(HasAttrBuiltin));
        self.register_builtin(Box::new(GetAttrBuiltin));
        self.register_builtin(Box::new(ConcatListsBuiltin));
        self.register_builtin(Box::new(ConcatStringsSepBuiltin));
        self.register_builtin(Box::new(AbortBuiltin));
        self.register_builtin(Box::new(TraceBuiltin));
        self.register_builtin(Box::new(StringLengthBuiltin));
        self.register_builtin(Box::new(AddBuiltin));
        self.register_builtin(Box::new(SubBuiltin));
        self.register_builtin(Box::new(MulBuiltin));
        self.register_builtin(Box::new(DivBuiltin));
        self.register_builtin(Box::new(CompareVersionsBuiltin));
        self.register_builtin(Box::new(CeilBuiltin));
        self.register_builtin(Box::new(FloorBuiltin));
        self.register_builtin(Box::new(ParseDrvNameBuiltin));
        self.register_builtin(Box::new(FoldlStrictBuiltin));
        self.register_builtin(Box::new(ElemAtBuiltin));
        self.register_builtin(Box::new(SubstringBuiltin));
        self.register_builtin(Box::new(ReplaceStringsBuiltin));
        self.register_builtin(Box::new(SplitBuiltin));
        self.register_builtin(Box::new(SplitVersionBuiltin));
        self.register_builtin(Box::new(crate::builtins::DerivationBuiltin));
        self.register_builtin(Box::new(crate::builtins::StorePathBuiltin));
        self.register_builtin(Box::new(crate::builtins::PathBuiltin));
        self.register_builtin(Box::new(crate::builtins::GenListBuiltin));
        self.register_builtin(Box::new(crate::builtins::AllBuiltin));
        self.register_builtin(Box::new(crate::builtins::AnyBuiltin));
        self.register_builtin(Box::new(crate::builtins::FilterBuiltin));
        self.register_builtin(Box::new(crate::builtins::BaseNameOfBuiltin));
        self.register_builtin(Box::new(crate::builtins::TryEvalBuiltin));
        self.register_builtin(Box::new(crate::builtins::ThrowBuiltin));
        self.register_builtin(Box::new(crate::builtins::MapBuiltin));
        self.register_builtin(Box::new(crate::builtins::BitOrBuiltin));
        self.register_builtin(Box::new(crate::builtins::BitAndBuiltin));
        self.register_builtin(Box::new(crate::builtins::BitXorBuiltin));
        self.register_builtin(Box::new(crate::builtins::ConcatMapBuiltin));
        self.register_builtin(Box::new(crate::builtins::NixVersionBuiltin));
        self.register_builtin(Box::new(crate::builtins::ToJSONBuiltin));
        self.register_builtin(Box::new(crate::builtins::ListToAttrsBuiltin));
        self.register_builtin(Box::new(crate::builtins::SeqBuiltin));
    }

    /// Get a builtin function by name
    pub(crate) fn get_builtin(&self, name: &str) -> Option<&Box<dyn Builtin>> {
        self.builtins.get(name)
    }

    /// Check if a path is a valid Nix store path
    ///
    /// A valid Nix store path has the format: `/nix/store/<hash>-<name>`
    /// where:
    /// - `<hash>` is a 32-character base32-encoded hash
    /// - `<name>` is the rest of the path component (can contain any characters except `/`)
    /// - The hash and name are separated by a single `-`
    pub(crate) fn is_valid_store_path(&self, path: &str) -> bool {
        if !path.starts_with("/nix/store/") {
            return false;
        }

        // Extract the part after /nix/store/
        let store_part = &path[11..]; // Length of "/nix/store/"

        // Find the first `-` which separates hash from name
        if let Some(dash_pos) = store_part.find('-') {
            // Hash is everything before the dash
            let hash = &store_part[..dash_pos];
            // Name is everything after the dash
            let name = &store_part[dash_pos + 1..];

            // Hash must be exactly 32 characters (base32 encoded)
            hash.len() == 32 && !name.is_empty()
        } else {
            false
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

    fn parse_nix_path(&mut self) {
        if let Ok(nix_path) = std::env::var("NIX_PATH") {
            for entry in nix_path.split(':') {
                // Skip empty entries
                if entry.is_empty() {
                    continue;
                }

                // Split on '=' to get name and path
                if let Some((name, path_str)) = entry.split_once('=') {
                    // Handle flake: protocol references
                    if path_str.starts_with("flake:") {
                        // Try to resolve flake reference using nix command
                        // Format: flake:name or flake:name#output
                        let flake_ref = if let Some(flake_name) = path_str.strip_prefix("flake:") {
                            flake_name.split('#').next().unwrap_or(flake_name)
                        } else {
                            continue;
                        };

                        // Try to resolve using nix flake metadata or nix-instantiate
                        if let Ok(resolved_path) = Self::resolve_flake_path(flake_ref) {
                            self.search_paths.insert(name.to_string(), resolved_path);
                        } else {
                            // If resolution fails, skip this entry
                            // TODO: Log warning or provide better error handling
                            continue;
                        }
                    } else {
                        // Regular path
                        let path = PathBuf::from(path_str);
                        self.search_paths.insert(name.to_string(), path);
                    }
                }
            }
        }
    }

    fn resolve_flake_path(flake_ref: &str) -> std::io::Result<PathBuf> {
        use std::process::Command;

        // Try using nix flake metadata first (for flakes)
        if let Ok(output) = Command::new("nix")
            .args(&["flake", "metadata", "--json", "--flake", flake_ref])
            .output()
        {
            if output.status.success() {
                // Parse JSON output to get path
                if let Ok(json) = std::str::from_utf8(&output.stdout) {
                    if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(json) {
                        if let Some(path_str) = parsed.get("path").and_then(|p| p.as_str()) {
                            return Ok(PathBuf::from(path_str));
                        }
                    }
                }
            }
        }

        // Fallback: try nix-instantiate for traditional NIX_PATH resolution
        if let Ok(output) = Command::new("nix-instantiate")
            .args(&["--eval", "-E", &format!("<{}>", flake_ref)])
            .output()
        {
            if output.status.success() {
                let path_str = std::str::from_utf8(&output.stdout)
                    .unwrap_or("")
                    .trim()
                    .trim_matches('"');
                if !path_str.is_empty() && path_str.starts_with('/') {
                    return Ok(PathBuf::from(path_str));
                }
            }
        }

        Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("could not resolve flake reference: {}", flake_ref),
        ))
    }

    /// Parse NIX_PATH environment variable and configure search paths
    ///
    /// NIX_PATH format: "name1=path1:name2=path2:..."
    /// Example: "nixpkgs=/path/to/nixpkgs:other=/path/to/other"

    pub(crate) fn current_file_path(&self) -> Option<PathBuf> {
        let context_stack = self.context_stack.borrow();
        let file_id_to_path = self.file_id_to_path.borrow();
        context_stack
            .last()
            .and_then(|ctx| ctx.file_id)
            .and_then(|file_id| file_id_to_path.get(&file_id).cloned())
    }

    pub(crate) fn current_file_id(&self) -> Option<FileId> {
        self.context_stack
            .borrow()
            .last()
            .and_then(|ctx| ctx.file_id)
    }

    pub(crate) fn push_context(&self, file_id: Option<FileId>, scope: VariableScope) {
        self.context_stack
            .borrow_mut()
            .push(EvaluationContext { file_id, scope });
    }

    pub(crate) fn pop_context(&self) -> Option<EvaluationContext> {
        self.context_stack.borrow_mut().pop()
    }

    /// Resolve a flake reference to a file system path
    ///
    /// Attempts to resolve flake references like "nixpkgs" to actual file system paths

    pub fn set_scope(&mut self, scope: VariableScope) {
        self.scope = scope;
    }

    /// Get a reference to the current variable scope
    ///
    /// # Returns
    ///

    pub fn scope(&self) -> &VariableScope {
        &self.scope
    }

    /// Get a mutable reference to the current variable scope
    ///
    /// This allows modifying the scope without replacing it entirely.
    ///
    /// # Returns
    ///

    pub fn scope_mut(&mut self) -> &mut VariableScope {
        &mut self.scope
    }

    /// Add a search path for resolving `<name>` style imports
    ///
    /// Search paths allow using syntax like `<nixpkgs>` to reference paths
    /// without specifying the full path. This is commonly used for nixpkgs.
    ///
    /// # Arguments
    ///
    /// * `name` - The search path name (e.g., "nixpkgs")
    /// * `path` - The actual path to resolve to
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::Evaluator;
    /// use std::path::PathBuf;
    ///
    /// let mut evaluator = Evaluator::new();
    /// evaluator.add_search_path("nixpkgs", PathBuf::from("/path/to/nixpkgs"));

    pub fn add_search_path(&mut self, name: impl Into<String>, path: PathBuf) {
        self.search_paths.insert(name.into(), path);
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

    /// Evaluate a Nix expression from a file
    ///
    /// This method sets up the file context so that relative imports can be resolved.
    /// It reads the file, parses it, and evaluates it with the proper file context.
    ///
    /// # Arguments
    ///
    /// * `file_path` - Path to the Nix file to evaluate
    ///
    /// # Returns
    ///
    /// * `Ok(NixValue)` - The evaluated value
    /// * `Err(Error)` - An error if reading, parsing, or evaluation fails
    pub fn evaluate_from_file(&self, file_path: &PathBuf) -> Result<NixValue> {
        // Read the file
        let code =
            std::fs::read_to_string(file_path).map_err(|e| Error::UnsupportedExpression {
                reason: format!("cannot read file '{}': {}", file_path.display(), e),
            })?;

        // Get canonical path
        let canonical_path = file_path
            .canonicalize()
            .unwrap_or_else(|_| file_path.clone());

        // Add file to source map and get file ID
        let file_id = {
            let mut source_map = self.source_map.borrow_mut();
            let file_name = canonical_path.to_string_lossy().to_string();
            let file_id = source_map.add(file_name, code.clone());
            // Store the mapping from file_id to path
            {
                let mut file_id_to_path = self.file_id_to_path.borrow_mut();
                file_id_to_path.insert(file_id, canonical_path.clone());
            }
            file_id
        };

        // Parse the code
        let tokens = tokenize(&code);
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

        // Push context for this file
        self.push_context(Some(file_id), self.scope.clone());

        // Evaluate the expression
        let result = self.evaluate_expr(&expr);

        // Pop context (restore previous context)
        self.pop_context();

        result
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

    pub(crate) fn evaluate_expr(&self, expr: &Expr) -> Result<NixValue> {
        self.evaluate_expr_with_scope_impl(expr, &self.scope)
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

    /// Internal implementation that evaluates an expression with a specific scope
    pub(crate) fn evaluate_expr_with_scope_impl(
        &self,
        expr: &Expr,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        match expr {
            Expr::Literal(literal) => self.evaluate_literal(literal),
            Expr::Str(str_expr) => self.evaluate_string(str_expr, scope),
            Expr::Ident(ident) => {
                // Handle identifiers (true, false, null, variables, builtins)
                // IMPORTANT: Check scope first! Variables in scope (including shadowed builtins)
                // take precedence over builtin values.
                let text = ident.to_string();

                // Check if it's a variable in scope first (scope takes precedence)
                if let Some(value) = scope.get(&text) {
                    return Ok(value.clone());
                }

                // If not in scope, check for builtin values
                match text.as_str() {
                    "true" => Ok(NixValue::Boolean(true)),
                    "false" => Ok(NixValue::Boolean(false)),
                    "null" => Ok(NixValue::Null),
                    "builtins" => {
                        // Return an attribute set containing all builtin functions
                        // Each builtin is accessible via builtins.<name>
                        // We'll handle this specially in evaluate_select and evaluate_apply
                        let mut builtins_attrs = HashMap::new();
                        for (name, _builtin) in &self.builtins {
                            // Store a marker that we can detect in evaluate_select
                            builtins_attrs.insert(
                                name.clone(),
                                NixValue::String(format!("__builtin:{}", name)),
                            );
                        }
                        // Add builtins.builtins pointing to itself (recursive reference)
                        // We'll use a special marker that evaluate_select will recognize
                        builtins_attrs.insert(
                            "builtins".to_string(),
                            NixValue::String("__builtins_self__".to_string()),
                        );
                        Ok(NixValue::AttributeSet(builtins_attrs))
                    }
                    _ => {
                        // Check if it's a builtin function
                        // For builtins that need special handling (map, all, any, etc.), we return
                        // a marker string so evaluate_apply can handle them specially
                        if self.builtins.contains_key(&text) {
                            // Builtins that need evaluator context return a marker
                            if text == "map"
                                || text == "all"
                                || text == "any"
                                || text == "filter"
                                || text == "concatMap"
                                || text == "catAttrs"
                                || text == "attrValues"
                                || text == "tryEval"
                            {
                                // Return a marker so evaluate_apply can handle it
                                return Ok(NixValue::String(format!("__direct_builtin:{}", text)));
                            }
                            // Other builtins are functions, not values - they need to be called
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
            Expr::AttrSet(set) => self.evaluate_attr_set(set, scope),
            Expr::List(list) => self.evaluate_list(list, scope),
            Expr::Lambda(lambda) => self.evaluate_lambda(lambda, scope),
            Expr::Apply(apply) => self.evaluate_apply(apply, scope),
            Expr::LetIn(let_in) => self.evaluate_let_in(let_in, scope),
            Expr::LegacyLet(legacy_let) => self.evaluate_legacy_let(legacy_let, scope),
            Expr::With(with) => self.evaluate_with(with, scope),
            Expr::IfElse(if_else) => self.evaluate_if_else(if_else, scope),
            Expr::Assert(assert) => self.evaluate_assert(assert, scope),
            Expr::Path(path_expr) => self.evaluate_path(path_expr, scope),
            Expr::Select(select) => self.evaluate_select(select, scope),
            Expr::HasAttr(has_attr) => self.evaluate_has_attr(has_attr, scope),
            Expr::BinOp(binop) => self.evaluate_binop(binop, scope),
            Expr::Paren(paren) => self.evaluate_paren(paren, scope),
            Expr::UnaryOp(unary_op) => self.evaluate_unary_op(unary_op, scope),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("{:?}", expr),
            }),
        }
    }

    // String and literal evaluation methods are in expressions/literals.rs
}

// NixValue force methods (moved here to avoid circular dependencies)
impl crate::value::NixValue {
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
    pub fn force(self, evaluator: &crate::eval::Evaluator) -> Result<NixValue> {
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
    pub fn get_attr(
        self,
        key: &str,
        evaluator: &crate::eval::Evaluator,
    ) -> Result<Option<NixValue>> {
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

    /// Deep force evaluation of this value and all nested thunks
    ///
    /// Recursively forces all thunks in this value, including those nested in
    /// lists and attribute sets. This is useful for fully evaluating a value
    /// before serialization or comparison.
    ///
    /// # Arguments
    ///
    /// * `evaluator` - The evaluator to use for forcing thunks
    ///
    /// # Returns
    ///
    /// The fully evaluated value or an error
    pub fn deep_force(self, evaluator: &crate::eval::Evaluator) -> Result<NixValue> {
        // Keep forcing until we get a non-thunk value
        let mut value = self.force(evaluator)?;
        while let NixValue::Thunk(thunk) = &value {
            value = thunk.force(evaluator)?;
        }

        // Now recursively force nested structures
        match value {
            NixValue::List(list) => {
                let mut forced_list = Vec::new();
                for item in list {
                    forced_list.push(item.deep_force(evaluator)?);
                }
                Ok(NixValue::List(forced_list))
            }
            NixValue::AttributeSet(mut attrs) => {
                let mut forced_attrs = HashMap::new();
                for (key, value) in attrs.drain() {
                    forced_attrs.insert(key, value.deep_force(evaluator)?);
                }
                Ok(NixValue::AttributeSet(forced_attrs))
            }
            other => Ok(other),
        }
    }
}
