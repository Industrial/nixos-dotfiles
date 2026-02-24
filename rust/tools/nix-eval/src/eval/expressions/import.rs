//! Import expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::value::NixValue;
use codespan::FileId;
use rnix::ast::Root;
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rnix::SyntaxNode;
use rowan::ast::AstNode;
use std::path::{Path, PathBuf};

impl Evaluator {
    pub(crate) fn import_file(&self, file_path: &Path) -> Result<NixValue> {
        // Resolve the path to import
        // First, try to resolve relative paths based on current_file context
        let resolved_path = if file_path.is_absolute() {
            file_path.to_path_buf()
        } else {
            // Relative path - resolve relative to current file
            if let Some(current_file_path) = self.current_file_path() {
                current_file_path
                    .parent()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "cannot resolve relative path: current file has no parent"
                            .to_string(),
                    })?
                    .join(file_path)
            } else {
                // No current file, use as-is (will be relative to CWD)
                file_path.to_path_buf()
            }
        };

        // Check if the path is a directory, and if so, append /default.nix
        // This matches the official Nix behavior where `import ./dir` becomes `import ./dir/default.nix`
        // Try to canonicalize the path as-is first
        let normalized_path = match resolved_path.canonicalize() {
            Ok(path) => {
                // Path exists - check if it's a directory
                if path.is_dir() {
                    // It's a directory, append /default.nix
                    path.join("default.nix")
                        .canonicalize()
                        .map_err(|e| Error::UnsupportedExpression {
                            reason: format!(
                                "cannot resolve import path '{}': directory exists but default.nix not found: {}",
                                file_path.display(),
                                e
                            ),
                        })?
                } else {
                    // It's a file, use it as-is
                    path
                }
            }
            Err(e) => {
                // Path doesn't exist as-is, try with /default.nix appended (might be a directory)
                let dir_with_default = resolved_path.join("default.nix");
                match dir_with_default.canonicalize() {
                    Ok(path) => path,
                    Err(_) => {
                        // Neither the path nor path/default.nix exists
                        // Provide better error message with context
                        let current_file_info =
                            if let Some(current_file_path) = self.current_file_path() {
                                format!(" (current file: {})", current_file_path.display())
                            } else {
                                " (no current file context)".to_string()
                            };
                        return Err(Error::UnsupportedExpression {
                            reason: format!(
                                "cannot resolve import path '{}': {} (resolved to: {}){}",
                                file_path.display(),
                                e,
                                resolved_path.display(),
                                current_file_info
                            ),
                        });
                    }
                }
            }
        };

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

        // Parse and evaluate the file (use reference for parsing, then move to source map)
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

        // Add file to source map and get file ID (move file_contents here)
        let file_id = {
            let mut source_map = self.source_map.borrow_mut();
            let file_name = normalized_path.to_string_lossy().to_string();
            let file_id = source_map.add(file_name, file_contents);
            // Store the mapping from file_id to path
            {
                let mut file_id_to_path = self.file_id_to_path.borrow_mut();
                file_id_to_path.insert(file_id, normalized_path.clone());
            }
            file_id
        };

        // Push context for this file
        self.push_context(Some(file_id), self.scope.clone());

        // Evaluate the expression
        // Note: Imported files should have their own scope, but for now we'll use the current scope
        let result = self.evaluate_expr_with_scope(&expr, &self.scope);

        // Pop context (restore previous context)
        self.pop_context();

        // Unwrap result after popping context
        let result = result?;

        // Cache the result
        {
            let mut cache = self.import_cache.borrow_mut();
            cache.insert(normalized_path, result.clone());
        }

        Ok(result)
    }
}
