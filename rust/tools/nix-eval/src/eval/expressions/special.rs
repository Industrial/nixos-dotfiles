//! Special form expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use crate::thunk;
use rnix::ast::{LetIn, LegacyLet, With, IfElse, Assert, Paren, Select, HasAttr, Expr, HasEntry, Attr};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;

impl Evaluator {
        pub(crate) fn evaluate_let_in(
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
        
        // Track variable names for legacy let expressions
        let mut var_names = Vec::new();

        // First pass: Collect all bindings and handle nested attribute paths
        // In Nix, let bindings can reference each other, so we need to create thunks
        // that will be evaluated lazily when accessed.
        // We also need to handle nested paths like `set.a.b = value`
        use std::collections::HashMap;
        let mut nested_bindings: HashMap<String, Vec<(Vec<String>, rnix::ast::Expr)>> = HashMap::new();
        
        for binding in bindings {
            // Get the attribute path (the variable name)
            let attrpath = binding
                .attrpath()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "let binding missing attrpath".to_string(),
                })?;

            // Collect all attribute names from the path
            let mut attr_names = Vec::new();
            for attr in attrpath.attrs() {
                let attr_str = attr.to_string();
                // Check if it's a string literal (starts and ends with quotes)
                if attr_str.starts_with('"') && attr_str.ends_with('"') && attr_str.len() >= 2 {
                    // Strip quotes for string literal attribute names
                    attr_names.push(attr_str[1..attr_str.len()-1].to_string());
                } else {
                    attr_names.push(attr_str);
                }
            }

            if attr_names.is_empty() {
                return Err(Error::UnsupportedExpression {
                    reason: "let binding variable name must be an identifier or string".to_string(),
                });
            }

            // Get the value expression
            let value_expr = binding
                .value()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: format!("let binding missing value"),
                })?;

            let var_name = attr_names[0].clone();
            
            if attr_names.len() == 1 {
                // Simple binding: var = value
                // Create a thunk for this binding
                let file_id = self.current_file_id();
                let thunk = thunk::Thunk::new(&value_expr, new_scope.clone(), file_id);
                new_scope.insert(var_name.clone(), NixValue::Thunk(Arc::new(thunk)));
                var_names.push(var_name);
            } else {
                // Nested binding: var.a.b = value
                // Store it for later processing
                nested_bindings.entry(var_name.clone())
                    .or_insert_with(Vec::new)
                    .push((attr_names, value_expr));
                if !var_names.contains(&var_name) {
                    var_names.push(var_name);
                }
            }
        }
        
        // Second pass: Handle nested bindings by creating attribute sets
        for (var_name, paths_and_values) in nested_bindings {
            // Build the nested attribute set structure
            // Start with an empty attribute set that will be merged into
            let mut attrs = HashMap::new();
            
            for (attr_names, value_expr) in paths_and_values {
                // Create a thunk for the value
                let file_id = self.current_file_id();
                let thunk = thunk::Thunk::new(&value_expr, new_scope.clone(), file_id);
                let mut nested_value = NixValue::Thunk(Arc::new(thunk));
                
                // Build nested structure from inside out
                // For "set.a.b = value", attr_names = ["set", "a", "b"]
                // We want to build { a = { b = value } }
                // So we iterate over ["a", "b"] in reverse: ["b", "a"]
                let nested_path = &attr_names[1..];
                for key in nested_path.iter().rev() {
                    let mut inner_map = HashMap::new();
                    inner_map.insert(key.clone(), nested_value);
                    nested_value = NixValue::AttributeSet(inner_map);
                }
                
                // nested_value now contains the full structure, e.g., { a = { b = value } }
                // Merge it into attrs (which will become the value of var_name)
                if let NixValue::AttributeSet(new_map) = nested_value {
                    // Deep merge: merge each key recursively
                    for (k, v) in new_map {
                        if let Some(existing) = attrs.get_mut(&k) {
                            // Merge recursively if both are attribute sets
                            if let NixValue::AttributeSet(existing_map) = existing {
                                if let NixValue::AttributeSet(new_inner_map) = &v {
                                    for (inner_k, inner_v) in new_inner_map {
                                        existing_map.insert(inner_k.clone(), inner_v.clone());
                                    }
                                } else {
                                    // Overwrite if types don't match
                                    *existing = v.clone();
                                }
                            } else {
                                // Overwrite if existing is not an attribute set
                                *existing = v.clone();
                            }
                        } else {
                            attrs.insert(k, v);
                        }
                    }
                }
            }
            
            // Store the attribute set in the scope
            new_scope.insert(var_name, NixValue::AttributeSet(attrs));
        }

        // Check if this is a legacy let expression (no "in" clause)
        // Legacy let expressions return the attribute set itself, with a special "body" attribute
        if let_in.body().is_none() {
            // Legacy let: build an attribute set from the bindings and return the "body" attribute
            use std::collections::HashMap;
            let mut attrs = HashMap::new();
            
            // Build attribute set from the scope (all bindings are already in new_scope)
            for var_name in var_names {
                if let Some(value) = new_scope.get(&var_name) {
                    attrs.insert(var_name, value.clone());
                }
            }

            // Extract the "body" attribute from the attribute set
            if let Some(body_value) = attrs.remove("body") {
                // Force the body thunk and return it
                // The body thunk can access other bindings through its closure (new_scope)
                body_value.force(self)
            } else {
                Err(Error::UnsupportedExpression {
                    reason: "legacy let expression must have a 'body' attribute".to_string(),
                })
            }
        } else {
            // Modern let: evaluate the body expression in the new scope
            let body_expr = let_in.body().ok_or_else(|| Error::UnsupportedExpression {
                reason: "let-in missing body expression".to_string(),
            })?;

            // Evaluate the body expression in the new scope
            // When bindings are accessed, their thunks will be forced and evaluated
            self.evaluate_expr_with_scope(&body_expr, &new_scope)
        }
    }

    /// Evaluate a legacy let expression
    ///
    /// Legacy let expressions like `let { x = 1; body = x; }` don't have an "in" clause.
    /// Instead, they return the attribute set itself, with a special "body" attribute
    /// that contains the result value.
    ///
    /// # Arguments
    ///
    /// * `legacy_let` - The legacy let AST node
    /// * `scope` - The current variable scope
    ///
    /// # Returns
    ///
    /// The evaluated "body" attribute value
    pub(crate) fn evaluate_legacy_let(
        &self,
        legacy_let: &rnix::ast::LegacyLet,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the bindings (the "let" part)
        // attrpath_values() returns an iterator over the bindings
        let bindings = legacy_let.attrpath_values();

        // Create a new scope that starts with the current scope
        // Bindings will be added to this scope as we evaluate them
        let mut new_scope = scope.clone();
        
        // Track variable names for building the attribute set
        let mut var_names = Vec::new();

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
            // Handle both identifiers and string literals (e.g., "foo bar")
            let var_name = attrpath
                .attrs()
                .next()
                .map(|attr| {
                    let attr_str = attr.to_string();
                    // Check if it's a string literal (starts and ends with quotes)
                    if attr_str.starts_with('"') && attr_str.ends_with('"') && attr_str.len() >= 2 {
                        // Strip quotes for string literal attribute names
                        attr_str[1..attr_str.len()-1].to_string()
                    } else {
                        attr_str
                    }
                })
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "let binding variable name must be an identifier or string".to_string(),
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
            let file_id = self.current_file_id();
            let thunk = thunk::Thunk::new(&value_expr, new_scope.clone(), file_id);

            // Add the thunk to the scope (wrapped in NixValue::Thunk)
            new_scope.insert(var_name.clone(), NixValue::Thunk(Arc::new(thunk)));
            var_names.push(var_name);
        }

        // Legacy let: build an attribute set from the bindings and return the "body" attribute
        use std::collections::HashMap;
        let mut attrs = HashMap::new();
        
        // Build attribute set from the scope (all bindings are already in new_scope)
        for var_name in var_names {
            if let Some(value) = new_scope.get(&var_name) {
                attrs.insert(var_name, value.clone());
            }
        }

        // Extract the "body" attribute from the attribute set
        if let Some(body_value) = attrs.remove("body") {
            // Force the body thunk and return it
            // The body thunk can access other bindings through its closure (new_scope)
            body_value.force(self)
        } else {
            Err(Error::UnsupportedExpression {
                reason: "legacy let expression must have a 'body' attribute".to_string(),
            })
        }
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


        pub(crate) fn evaluate_with(&self, with: &rnix::ast::With, scope: &VariableScope) -> Result<NixValue> {
        // Get the attribute set expression (the "with" part)
        let attrset_expr = with
            .namespace()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "with expression missing namespace".to_string(),
            })?;

        // Evaluate the attribute set expression
        let attrset_value = self.evaluate_expr_with_scope(&attrset_expr, scope)?;
        
        // Force thunks before checking if it's an attribute set
        let attrset_forced = attrset_value.force(self)?;

        // Extract the attribute set
        let attrs = match attrset_forced {
            NixValue::AttributeSet(attrs) => attrs,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!(
                        "with expression namespace must be an attribute set, got: {:?}",
                        attrset_forced
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
        self.evaluate_expr_with_scope(&body_expr, &new_scope)
    }

    /// Evaluate an assert expression
    ///
    /// An assert expression like `assert condition; body` evaluates the condition
    /// and if it's truthy, evaluates and returns the body. If the condition is falsy,
    /// it throws an error.
    ///
    /// # Arguments
    ///
    /// * `assert` - The assert AST node
    /// * `scope` - The current variable scope
    ///
    /// # Returns
    ///
    /// The evaluated body value if condition is truthy, or an error if falsy
    pub(crate) fn evaluate_assert(
        &self,
        assert: &rnix::ast::Assert,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the condition expression
        let condition_expr = assert.condition().ok_or_else(|| Error::UnsupportedExpression {
            reason: "assert expression missing condition".to_string(),
        })?;

        // Evaluate and force the condition (thunks must be forced)
        let condition_value = self.evaluate_expr_with_scope(&condition_expr, scope)?;
        let condition_forced = condition_value.force(self)?;

        // Check if condition is truthy
        // In Nix, only `false` and `null` are falsy
        let is_truthy = match condition_forced {
            NixValue::Boolean(false) => false,
            NixValue::Null => false,
            _ => true,
        };

        if !is_truthy {
            return Err(Error::UnsupportedExpression {
                reason: "assertion failed".to_string(),
            });
        }

        // Get the body expression
        let body_expr = assert.body().ok_or_else(|| Error::UnsupportedExpression {
            reason: "assert expression missing body".to_string(),
        })?;

        // Evaluate and return the body
        self.evaluate_expr_with_scope(&body_expr, scope)
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


        pub(crate) fn evaluate_path(
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
            if let Some(current_file_path) = self.current_file_path() {
                current_file_path
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


        pub(crate) fn evaluate_select(
        &self,
        select: &rnix::ast::Select,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the expression being selected from
        let expr = select.expr().ok_or_else(|| Error::UnsupportedExpression {
            reason: "select expression missing base expression".to_string(),
        })?;

        // Evaluate the base expression
        let base_value_raw = self.evaluate_expr_with_scope(&expr, scope)?;
        
        // Force thunks before checking if it's an attribute set
        let base_value = base_value_raw.force(self)?;

        // Get the attribute path
        let attrpath = select
            .attrpath()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "select expression missing attrpath".to_string(),
            })?;

        // Get the first attribute name
        // Handle both identifiers and string literals
        let attr_node = attrpath
            .attrs()
            .next()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "select attrpath must have at least one attribute".to_string(),
            })?;
        
        // Get the syntax node from the attribute using rowan's AstNode trait
        use rowan::ast::AstNode;
        let attr_syntax = attr_node.syntax();
        
        let attr_name = if let Some(ident) = rnix::ast::Ident::cast(attr_syntax.clone()) {
            // Regular identifier
            ident.to_string()
        } else if let Some(str_node) = rnix::ast::Str::cast(attr_syntax.clone()) {
            // String literal - evaluate it to get the key
            let str_value = self.evaluate_string(&str_node, scope)?;
            match str_value {
                NixValue::String(s) => s,
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: "attribute name must be a string".to_string(),
                    });
                }
            }
        } else if let Some(expr) = rnix::ast::Expr::cast(attr_syntax.clone()) {
            // Dynamic attribute name - evaluate it
            let expr_value = self.evaluate_expr_with_scope(&expr, scope)?;
            let forced_value = expr_value.force(self)?;
            match forced_value {
                NixValue::String(s) => s,
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: "attribute name must evaluate to a string".to_string(),
                    });
                }
            }
        } else {
            // Fallback: try to get text representation
            attr_syntax.text().to_string().trim_matches('"').to_string()
        };

        // Access the attribute from the attribute set
        match base_value {
            NixValue::AttributeSet(mut attrs) => {
                if let Some(value) = attrs.remove(&attr_name) {
                    // Check if this is a builtin marker (from builtins.<name> access)
                    if let NixValue::String(ref s) = value {
                        if s.starts_with("__builtin:") {
                            let builtin_name = &s[10..]; // Skip "__builtin:"
                            // Verify the builtin exists
                            if self.builtins.contains_key(builtin_name) {
                                // Return a marker that evaluate_apply will recognize
                                return Ok(NixValue::String(format!("__builtin_func:{}", builtin_name)));
                            }
                        } else if s == "__builtins_self__" {
                            // builtins.builtins should return the builtins attribute set itself
                            // Reconstruct the builtins attribute set
                            let mut builtins_attrs = HashMap::new();
                            for (name, _builtin) in &self.builtins {
                                builtins_attrs.insert(name.clone(), NixValue::String(format!("__builtin:{}", name)));
                            }
                            // Add builtins.builtins pointing to itself (recursive)
                            builtins_attrs.insert("builtins".to_string(), NixValue::String("__builtins_self__".to_string()));
                            return Ok(NixValue::AttributeSet(builtins_attrs));
                        }
                    }
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


        pub(crate) fn evaluate_if_else(
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
        let condition_value = self.evaluate_expr_with_scope(&condition_expr, scope)?;

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
            self.evaluate_expr_with_scope(&then_expr, scope)
        } else {
            // Evaluate the "else" branch
            let else_expr = if_else
                .else_body()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "if expression missing else branch".to_string(),
                })?;
            self.evaluate_expr_with_scope(&else_expr, scope)
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


        pub(crate) fn evaluate_paren(&self, paren: &Paren, scope: &VariableScope) -> Result<NixValue> {
        // Get the inner expression
        let inner_expr = paren.expr().ok_or_else(|| Error::UnsupportedExpression {
            reason: "parenthesized expression missing inner expression".to_string(),
        })?;
        
        // Evaluate the inner expression
        self.evaluate_expr_with_scope(&inner_expr, scope)
    }

}
