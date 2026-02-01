//! Special form expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use crate::thunk;
use rnix::ast::{LetIn, With, IfElse, Assert, Paren, Select, HasAttr, Expr, HasEntry};
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
            let file_id = self.current_file_id();
            let thunk = thunk::Thunk::new(&value_expr, new_scope.clone(), file_id);

            // Add the thunk to the scope (wrapped in NixValue::Thunk)
            new_scope.insert(var_name, NixValue::Thunk(Arc::new(thunk)));
        }

        // Get the body expression (the "in" part)
        let body_expr = let_in.body().ok_or_else(|| Error::UnsupportedExpression {
            reason: "let-in missing body expression".to_string(),
        })?;

        // Evaluate the body expression in the new scope
        // When bindings are accessed, their thunks will be forced and evaluated
        self.evaluate_expr_with_scope(&body_expr, &new_scope)
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
        self.evaluate_expr_with_scope(&body_expr, &new_scope)
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
        let base_value = self.evaluate_expr_with_scope(&expr, scope)?;

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
                    // Check if this is a builtin marker (from builtins.<name> access)
                    if let NixValue::String(ref s) = value {
                        if s.starts_with("__builtin:") {
                            let builtin_name = &s[10..]; // Skip "__builtin:"
                            // Verify the builtin exists
                            if self.builtins.contains_key(builtin_name) {
                                // Return a marker that evaluate_apply will recognize
                                return Ok(NixValue::String(format!("__builtin_func:{}", builtin_name)));
                            }
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
